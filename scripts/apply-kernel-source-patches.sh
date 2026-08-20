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

sp_enabled="$(jq -r --arg s "${KERNEL_SOURCE}" '.[$s].source_patches.enabled // false' "${CONFIG_JSON}")"
if [[ "${sp_enabled}" != "true" ]]; then
  echo "No source-local patches configured for ${KERNEL_SOURCE} (noop)."
  exit 0
fi

PATCH_DIR="$(jq -r --arg s "${KERNEL_SOURCE}" '.[$s].source_patches.dir // empty' "${CONFIG_JSON}")"
if [[ -z "${PATCH_DIR}" ]]; then
  echo "No source-local patches configured for ${KERNEL_SOURCE} (noop)."
  exit 0
fi

match_refs="$(jq -r --arg s "${KERNEL_SOURCE}" '.[$s].source_patches.match_refs // [] | if type=="array" then join(" ") else . end' "${CONFIG_JSON}")"
if [[ -n "${match_refs}" ]]; then
  matched=0
  for ref in ${match_refs}; do
    if [[ "${SOURCE_REF}" == "${ref}" ]]; then
      matched=1
      break
    fi
  done
  if [[ "${matched}" -ne 1 ]]; then
    echo "Skipping source patches for ${KERNEL_SOURCE}: SOURCE_REF='${SOURCE_REF}' not in match_refs (${match_refs})"
    echo "::notice::No source-local patches applied (ref gate)."
    exit 0
  fi
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
