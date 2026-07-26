#!/usr/bin/env bash
set -euo pipefail

# Resolve a numeric manager version code for packaging / summaries.
# Strategy (WildKernels-inspired):
#   1) Prefer Wild-style: git rev-list --count + BASE_VERSION, inject into Makefile
#   2) Fallback: literal KERNELSU_VERSION / KSU_VERSION in Makefile
# Soft warnings only — never fail the build if version cannot be resolved.

MANAGER="${MANAGER:-none}"
KERNEL_DIR="${KERNEL_DIR:-kernel-source}"
RESOLVED_REFS_FILE="${RESOLVED_REFS_FILE:-release/resolved-refs.env}"

manager_version_code=""
manager_version_method=""
mkdir -p "$(dirname "${RESOLVED_REFS_FILE}")"

write_empty() {
  echo "manager_version_code=" >> "${RESOLVED_REFS_FILE}"
}

if [[ "${MANAGER}" == "none" ]]; then
  echo "No manager — skipping version read"
  write_empty
  exit 0
fi

# Manager tree roots after setup.sh (order matters).
manager_root_candidates=(
  "${KERNEL_DIR}/KernelSU-Next"
  "${KERNEL_DIR}/KernelSU"
  "${KERNEL_DIR}/SukiSU-Ultra"
  "${KERNEL_DIR}/SukiSU"
  "${KERNEL_DIR}/ReSukiSU"
  "${KERNEL_DIR}/drivers/kernelsu"
)

manager_root=""
for candidate in "${manager_root_candidates[@]}"; do
  if [[ -d "${candidate}" ]]; then
    manager_root="${candidate}"
    break
  fi
done

makefile_candidates=(
  "${KERNEL_DIR}/KernelSU-Next/kernel/Makefile"
  "${KERNEL_DIR}/KernelSU/kernel/Makefile"
  "${KERNEL_DIR}/SukiSU-Ultra/kernel/Makefile"
  "${KERNEL_DIR}/SukiSU/kernel/Makefile"
  "${KERNEL_DIR}/ReSukiSU/kernel/Makefile"
  "${KERNEL_DIR}/drivers/kernelsu/Makefile"
)
if [[ -n "${manager_root}" && -f "${manager_root}/kernel/Makefile" ]]; then
  makefile_candidates=("${manager_root}/kernel/Makefile" "${makefile_candidates[@]}")
fi
if [[ -n "${manager_root}" && -f "${manager_root}/Makefile" ]]; then
  makefile_candidates=("${manager_root}/Makefile" "${makefile_candidates[@]}")
fi

manager_makefile=""
for candidate in "${makefile_candidates[@]}"; do
  if [[ -f "${candidate}" ]]; then
    manager_makefile="${candidate}"
    break
  fi
done

if [[ -z "${manager_makefile}" ]]; then
  echo "::warning::Manager Makefile not found in expected locations — version code will be empty"
  write_empty
  exit 0
fi

# Wild-style BASE_VERSION by manager family (matches common KSUN/KSU CI practice).
# Overridable via MANAGER_VERSION_BASE for experiments.
wild_base_for_manager() {
  local commits="$1"
  case "${MANAGER}" in
    kernelsu)
      echo "${MANAGER_VERSION_BASE:-30000}"
      ;;
    kernelsu-next|sukisu-ultra|resukisu)
      # Wild KSUN: older histories use 10200, newer use 30000 past ~2684 commits.
      if [[ -n "${MANAGER_VERSION_BASE:-}" ]]; then
        echo "${MANAGER_VERSION_BASE}"
      elif (( commits < 2684 )); then
        echo 10200
      else
        echo 30000
      fi
      ;;
    *)
      echo "${MANAGER_VERSION_BASE:-30000}"
      ;;
  esac
}

# Find a git directory to count commits (manager root or makefile dir).
git_dir_for_count=""
for d in "${manager_root}" "$(dirname "${manager_makefile}")" "$(dirname "$(dirname "${manager_makefile}")")"; do
  [[ -z "${d}" ]] && continue
  if git -C "${d}" rev-parse --git-dir >/dev/null 2>&1; then
    git_dir_for_count="${d}"
    break
  fi
done

if [[ -n "${git_dir_for_count}" ]]; then
  commits_count="$(git -C "${git_dir_for_count}" rev-list --count HEAD 2>/dev/null || true)"
  if [[ "${commits_count}" =~ ^[0-9]+$ ]] && (( commits_count > 0 )); then
    base_version="$(wild_base_for_manager "${commits_count}")"
    manager_version_code="$((commits_count + base_version))"
    manager_version_method="wild-revlist"
    echo "Wild-style manager version: commits=${commits_count} base=${base_version} code=${manager_version_code} (git: ${git_dir_for_count})"

    # Inject into Makefile so the built manager reports the same code (Wild pattern).
    # Common placeholders seen in KernelSU-family Makefiles.
    if grep -qE 'DKSU_VERSION\s*[?:]?=' "${manager_makefile}" 2>/dev/null; then
      sed -i -E "s/(DKSU_VERSION\\s*[?:]?=\\s*)[0-9]+/\\1${manager_version_code}/" "${manager_makefile}" || true
      echo "Injected DKSU_VERSION=${manager_version_code} into ${manager_makefile}"
    elif grep -qE '^(export[[:space:]]+)?KSU_VERSION\s*[?:]?=\s*[0-9]+' "${manager_makefile}" 2>/dev/null; then
      sed -i -E "s/^(export[[:space:]]+)?(KSU_VERSION\\s*[?:]?=\\s*)[0-9]+/\\1\\2${manager_version_code}/" "${manager_makefile}" || true
      echo "Injected KSU_VERSION=${manager_version_code} into ${manager_makefile}"
    elif grep -qE '^(export[[:space:]]+)?KERNELSU_VERSION\s*[?:]?=\s*[0-9]+' "${manager_makefile}" 2>/dev/null; then
      sed -i -E "s/^(export[[:space:]]+)?(KERNELSU_VERSION\\s*[?:]?=\\s*)[0-9]+/\\1\\2${manager_version_code}/" "${manager_makefile}" || true
      echo "Injected KERNELSU_VERSION=${manager_version_code} into ${manager_makefile}"
    else
      echo "Note: no DKSU_VERSION/KSU_VERSION numeric assignment to inject; computed code still recorded for packaging"
    fi
  fi
fi

# Fallback: literal numeric assignment already in Makefile (previous Marble behavior).
if [[ -z "${manager_version_code}" ]]; then
  manager_version_code="$(
    sed -nE 's/^[[:space:]]*(export[[:space:]]+)?(KERNELSU_VERSION|KSU_VERSION|DKSU_VERSION)[[:space:]]*[?:]?=[[:space:]]*([0-9]+)[[:space:]]*$/\3/p' \
      "${manager_makefile}" | head -n1 || true
  )"
  if [[ -n "${manager_version_code}" ]]; then
    manager_version_method="makefile-literal"
    echo "Literal manager version code from Makefile: ${manager_version_code}"
  fi
fi

if [[ -z "${manager_version_code}" ]]; then
  echo "::warning::Could not compute or read manager version code from ${manager_makefile}"
  write_empty
  exit 0
fi

{
  echo "manager_version_code=${manager_version_code}"
  echo "manager_version_method=${manager_version_method}"
  # Seed build metadata early so ZIP naming works even if log parse is empty.
  echo "manager_build_version_code=${manager_version_code}"
} >> "${RESOLVED_REFS_FILE}"

echo "Manager version code: ${manager_version_code} (method=${manager_version_method})"
