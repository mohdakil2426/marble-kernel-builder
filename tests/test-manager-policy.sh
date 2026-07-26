#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

expect_validation_failure() {
  local manager="$1"
  local enable_susfs="$2"

  if SOURCE_REPO=owner/repo \
     SOURCE_REF=main \
     MANAGER="${manager}" \
     ENABLE_SUSFS="${enable_susfs}" \
     bash scripts/validate-inputs.sh >/dev/null 2>&1; then
    fail "validation accepted manager=${manager} enable_susfs=${enable_susfs}"
  fi
}

expect_validation_success() {
  local manager="$1"
  local enable_susfs="$2"

  SOURCE_REPO=owner/repo \
  SOURCE_REF=main \
  MANAGER="${manager}" \
  ENABLE_SUSFS="${enable_susfs}" \
  bash scripts/validate-inputs.sh >/dev/null
}

if grep -q 'kernelsu-next-susfs\|"custom"' config/managers.json; then
  fail "legacy fork/custom manager choices remain selectable"
fi

if grep -q 'custom_manager_' .github/workflows/build-matrix.yml; then
  fail "custom manager workflow inputs remain selectable"
fi

python3 - <<'PY'
import json

with open("config/managers.json", encoding="utf-8") as handle:
    managers = json.load(handle)

expected = {
    "none": "",
    "kernelsu": "tiann/KernelSU",
    "kernelsu-next": "KernelSU-Next/KernelSU-Next",
    "sukisu-ultra": "SukiSU-Ultra/SukiSU-Ultra",
    "resukisu": "ReSukiSU/ReSukiSU",
}
actual = {name: entry["repo"] for name, entry in managers.items()}
if actual != expected:
    raise SystemExit(f"FAIL: manager allowlist mismatch: {actual!r}")

for name, entry in managers.items():
    if entry["repo"] == "pershoot/KernelSU-Next":
        raise SystemExit(f"FAIL: forked manager source is selectable as {name}")
PY

expect_validation_failure kernelsu-next-susfs true
expect_validation_failure custom false
expect_validation_failure kernelsu true
expect_validation_success none false
expect_validation_success kernelsu false
expect_validation_success kernelsu-next true
SOURCE_REPO=owner/repo \
SOURCE_REF=main \
MANAGER=kernelsu-next \
MANAGER_REF=dev-susfs \
ENABLE_SUSFS=true \
bash scripts/validate-inputs.sh >/dev/null
if SOURCE_REPO=owner/repo SOURCE_REF=main MANAGER=kernelsu-next MANAGER_REF=dev ENABLE_SUSFS=true \
   bash scripts/validate-inputs.sh >/dev/null 2>&1; then
  fail "validation accepted official KernelSU-Next dev with SUSFS"
fi
expect_validation_success sukisu-ultra true
expect_validation_success resukisu true

if SOURCE_REPO=owner/repo SOURCE_REF=main MANAGER=kernelsu-next ENABLE_SUSFS=true \
   MANAGER_REF=dev-susfs \
   SUSFS_KERNEL_BRANCH=gki-android14-6.1 bash scripts/validate-inputs.sh >/dev/null 2>&1; then
  fail "validation accepted a non-Marble SUSFS patch family"
fi

python3 - <<'PY'
import json

with open("config/managers.json", encoding="utf-8") as handle:
    managers = json.load(handle)

ksun = managers["kernelsu-next"]
if ksun.get("susfs_repo") != "pershoot/KernelSU-Next":
    raise SystemExit("FAIL: KernelSU-Next SUSFS repo must be pershoot/KernelSU-Next")
if ksun.get("susfs_ref") != "dev-susfs":
    raise SystemExit("FAIL: KernelSU-Next SUSFS ref must be dev-susfs")
PY

if ! grep -q 'manager-setup.sh "${manager_commit}"' scripts/patch-manager.sh; then
  fail "manager setup is not pinned to the resolved official commit"
fi

echo "Manager source policy tests passed"
