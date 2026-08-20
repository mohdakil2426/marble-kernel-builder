#!/usr/bin/env bash
# Policy + dry structure tests for source-local patches (no full kernel tree required).
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

PYTHON="${PYTHON:-python3}"
"${PYTHON}" - <<'PY'
import json
from pathlib import Path

presets = json.loads(Path("config/kernel-sources.json").read_text(encoding="utf-8"))
assert "pa-gr" in presets
sp = presets["pa-gr"].get("source_patches") or {}
assert sp.get("enabled") is True
assert sp.get("dir") == "patches/kernel-sources/pa-gr/vauxite"
assert "vauxite" in (sp.get("match_refs") or [])

# Only pa-gr should have source_patches for now
for name, preset in presets.items():
    if name == "pa-gr":
        continue
    assert not preset.get("source_patches"), f"{name} must not declare source_patches yet"

series = Path("patches/kernel-sources/pa-gr/vauxite/series").read_text(encoding="utf-8")
assert "0001-kvm-arm64-init-clidr-for-clang22.patch" in series
patch = Path("patches/kernel-sources/pa-gr/vauxite/0001-kvm-arm64-init-clidr-for-clang22.patch")
assert patch.is_file()
text = patch.read_text(encoding="utf-8")
assert "struct sys_reg_desc clidr = {0}" in text
assert "pa-gr" in text or "Clang 22" in text
print("source patch assets ok")
PY

# Noop path for melt (no patches)
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT
mkdir -p "${tmp}/kernel-source"
out="$(
  KERNEL_SOURCE=melt SOURCE_REF=melt-rebase KERNEL_DIR="${tmp}/kernel-source" \
    bash scripts/apply-kernel-source-patches.sh
)"
echo "${out}" | grep -qi 'noop\|No source-local' || {
  echo "FAIL: melt should skip source patches" >&2
  echo "${out}" >&2
  exit 1
}

# Ref mismatch for pa-gr
out="$(
  KERNEL_SOURCE=pa-gr SOURCE_REF=other-branch KERNEL_DIR="${tmp}/kernel-source" \
    bash scripts/apply-kernel-source-patches.sh
)"
echo "${out}" | grep -qi 'Skipping\|ref' || {
  echo "FAIL: pa-gr non-vauxite ref should skip" >&2
  echo "${out}" >&2
  exit 1
}

# Apply on a mini tree that contains the target hunk
mkdir -p "${tmp}/ks/arch/arm64/kvm"
cat >"${tmp}/ks/arch/arm64/kvm/sys_regs.c" <<'C'
void kvm_sys_reg_table_init(void)
{
	unsigned int i;
	struct sys_reg_desc clidr;

	/* Make sure tables are unique and in order. */
	BUG_ON(check_sysreg_table(sys_reg_descs, ARRAY_SIZE(sys_reg_descs), false));
}
C

KERNEL_SOURCE=pa-gr SOURCE_REF=vauxite KERNEL_DIR="${tmp}/ks" \
  bash scripts/apply-kernel-source-patches.sh >/dev/null

grep -q 'struct sys_reg_desc clidr = {0};' "${tmp}/ks/arch/arm64/kvm/sys_regs.c" || {
  echo "FAIL: patch did not initialize clidr" >&2
  cat "${tmp}/ks/arch/arm64/kvm/sys_regs.c" >&2
  exit 1
}

# Reject path: tree without matching hunk
mkdir -p "${tmp}/ks2/arch/arm64/kvm"
echo '/* empty */' >"${tmp}/ks2/arch/arm64/kvm/sys_regs.c"
if KERNEL_SOURCE=pa-gr SOURCE_REF=vauxite KERNEL_DIR="${tmp}/ks2" \
  bash scripts/apply-kernel-source-patches.sh >/dev/null 2>&1; then
  echo "FAIL: mismatched tree should reject patch" >&2
  exit 1
fi

echo "Source-local patch tests passed"
