#!/usr/bin/env bash
# Apply optional source-local patches for the selected kernel preset only.
# Patches live under patches/kernel-sources/<preset>/… and are ephemeral (CI workspace).
set -euo pipefail

KERNEL_SOURCE="${KERNEL_SOURCE:-melt}"
SOURCE_REF="${SOURCE_REF:-}"
KERNEL_DIR="${KERNEL_DIR:-kernel-source}"
CONFIG_JSON="${CONFIG_JSON:-config/kernel-sources.json}"

if [[ ! -f "${CONFIG_JSON}" ]]; then
  echo "::error::Missing ${CONFIG_JSON}"
  exit 1
fi

if [[ ! -d "${KERNEL_DIR}" ]]; then
  echo "::error::Kernel directory not found: ${KERNEL_DIR}"
  exit 1
fi

eval "$(
  KERNEL_SOURCE="${KERNEL_SOURCE}" SOURCE_REF="${SOURCE_REF}" python3 - "${CONFIG_JSON}" <<'PY'
import json
import os
import shlex
import sys

config_path = sys.argv[1]
kernel_source = os.environ.get("KERNEL_SOURCE", "melt")
source_ref = os.environ.get("SOURCE_REF", "")

with open(config_path, encoding="utf-8") as fh:
    presets = json.load(fh)

if kernel_source not in presets:
    print("APPLY=0")
    print("REASON=unknown_preset")
    sys.exit(0)

preset = presets[kernel_source]
sp = preset.get("source_patches") or {}
enabled = bool(sp.get("enabled"))
patch_dir = (sp.get("dir") or "").strip()
match_refs = sp.get("match_refs") or []
if isinstance(match_refs, str):
    match_refs = [match_refs]

if not enabled or not patch_dir:
    print("APPLY=0")
    print("REASON=disabled_or_empty")
    sys.exit(0)

if match_refs and source_ref not in match_refs:
    print("APPLY=0")
    print("REASON=ref_mismatch")
    print(f"MATCH_REFS={shlex.quote(' '.join(match_refs))}")
    print(f"SOURCE_REF={shlex.quote(source_ref)}")
    sys.exit(0)

print("APPLY=1")
print(f"PATCH_DIR={shlex.quote(patch_dir)}")
print(f"SOURCE_REF={shlex.quote(source_ref)}")
PY
)"

if [[ "${APPLY:-0}" != "1" ]]; then
  case "${REASON:-}" in
    ref_mismatch)
      echo "Skipping source patches for ${KERNEL_SOURCE}: SOURCE_REF='${SOURCE_REF}' not in match_refs (${MATCH_REFS:-})"
      echo "::notice::No source-local patches applied (ref gate)."
      ;;
    *)
      echo "No source-local patches configured for ${KERNEL_SOURCE} (noop)."
      ;;
  esac
  exit 0
fi

if [[ ! -d "${PATCH_DIR}" ]]; then
  echo "::error::source_patches.dir missing: ${PATCH_DIR}"
  exit 1
fi

series_file="${PATCH_DIR}/series"
if [[ ! -f "${series_file}" ]]; then
  echo "::error::Missing series file: ${series_file}"
  exit 1
fi

mapfile -t patch_names < <(
  grep -vE '^\s*(#|$)' "${series_file}" || true
)

if [[ "${#patch_names[@]}" -eq 0 ]]; then
  echo "series is empty under ${PATCH_DIR}; nothing to apply."
  exit 0
fi

echo "Applying source-local patches for ${KERNEL_SOURCE} @ ${SOURCE_REF} from ${PATCH_DIR}"
applied=0
for name in "${patch_names[@]}"; do
  patch_path="${PATCH_DIR}/${name}"
  if [[ ! -f "${patch_path}" ]]; then
    echo "::error::Patch listed in series but missing: ${patch_path}"
    exit 1
  fi
  echo "  → ${name}"
  # Fail hard on reject so a fixed upstream or drifted tree forces patch removal/update.
  if ! patch -p1 --forward --directory="${KERNEL_DIR}" <"${patch_path}"; then
    echo "::error::Failed to apply ${name} to ${KERNEL_DIR}."
    echo "::error::If upstream already fixed this, remove the patch from ${PATCH_DIR}/series and disable source_patches."
    exit 1
  fi
  applied=$((applied + 1))
done

echo "Applied ${applied} source-local patch(es) for ${KERNEL_SOURCE}."
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "### Source-local patches"
    echo "- preset: \`${KERNEL_SOURCE}\`"
    echo "- ref: \`${SOURCE_REF}\`"
    echo "- dir: \`${PATCH_DIR}\`"
    echo "- count: ${applied}"
  } >>"${GITHUB_STEP_SUMMARY}"
fi
