#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"
PYTHON="${PYTHON:-python3}"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "${haystack}" != *"${needle}"* ]]; then
    echo "FAIL: expected to find '${needle}' in output" >&2
    echo "${haystack}" >&2
    exit 1
  fi
}

# Default melt preset
out="$(
  cd "${tmp_dir}"
  mkdir -p config scripts release
  cp "${repo_root}/config/kernel-sources.json" config/
  cp "${repo_root}/scripts/resolve-kernel-source.sh" scripts/
  KERNEL_SOURCE=melt SOURCE_REF='' PYTHON="${PYTHON}" bash scripts/resolve-kernel-source.sh
  cat release/kernel-source.env
)"
assert_contains "${out}" "SOURCE_REPO=mohdakil2426/android_kernel_xiaomi_marble"
assert_contains "${out}" "SOURCE_REF=melt-rebase"
assert_contains "${out}" "DEFCONFIG_MODE=single"
assert_contains "${out}" "DEFCONFIG=marble_defconfig"
assert_contains "${out}" "SUPPORTED_ROM_LABEL=HyperOS"
assert_contains "${out}" "KERNEL_SOURCE_AUTHOR=Melt"

# LOS multi-fragment presets
for preset_repo in \
  "lineageos|LineageOS/android_kernel_xiaomi_sm8450|lineage-23.2|LineageOS" \
  "evolution-x|Evolution-X-Devices/kernel_xiaomi_sm8450|cnb|Evolution-X" \
  "aosp-pablo|aosp-pablo/android_kernel_xiaomi_sm8450|16|aosp-pablo" \
  "pa-gr|pa-gr/android_kernel_xiaomi_sm8450|vauxite|pa-gr"
do
  IFS='|' read -r preset repo ref author <<<"${preset_repo}"
  out="$(
    cd "${tmp_dir}"
    rm -rf release
    mkdir -p release
    KERNEL_SOURCE="${preset}" SOURCE_REF='' PYTHON="${PYTHON}" bash scripts/resolve-kernel-source.sh >/dev/null
    cat release/kernel-source.env
  )"
  assert_contains "${out}" "SOURCE_REPO=${repo}"
  assert_contains "${out}" "SOURCE_REF=${ref}"
  assert_contains "${out}" "DEFCONFIG_MODE=gki_fragments"
  assert_contains "${out}" "BASE_DEFCONFIG=gki_defconfig"
  assert_contains "${out}" "vendor/marble_GKI.config"
  assert_contains "${out}" "KERNEL_SOURCE_AUTHOR=${author}"
  assert_contains "${out}" "ROM_FAMILY=los"
done

# Optional source_ref override
out="$(
  cd "${tmp_dir}"
  rm -rf release
  mkdir -p release
  KERNEL_SOURCE=lineageos SOURCE_REF=lineage-23.1 PYTHON="${PYTHON}" bash scripts/resolve-kernel-source.sh >/dev/null
  cat release/kernel-source.env
)"
assert_contains "${out}" "SOURCE_REF=lineage-23.1"

# Unknown preset must fail
if KERNEL_SOURCE=not-a-real-preset SOURCE_REF='' PYTHON="${PYTHON}" bash scripts/resolve-kernel-source.sh >/dev/null 2>&1; then
  echo "FAIL: unknown kernel_source should be rejected" >&2
  exit 1
fi

# Package naming uses author/ROM labels
assert_name() {
  local expected="$1"
  shift
  local actual
  actual="$(env PACKAGE_NAME_ONLY=true GITHUB_RUN_NUMBER=9 "$@" bash scripts/package-anykernel.sh)"
  if [[ "${actual}" != "${expected}" ]]; then
    echo "FAIL: expected ${expected}, got ${actual}" >&2
    exit 1
  fi
}

assert_name \
  'AK3_marble_LOS_lineageos_ksunext-v3.2.0-code33203_susfs-v2.2.0_r9.zip' \
  KERNEL_SOURCE=lineageos ROM_FAMILY=los \
  MANAGER=kernelsu-next ENABLE_SUSFS=true \
  manager_build_version_name='v3.2.0' manager_build_version_code=33203 \
  susfs_reported_version=v2.2.0

assert_name \
  'AK3_marble_LOS_evolution-x_noroot_r9.zip' \
  KERNEL_SOURCE=evolution-x ROM_FAMILY=los \
  MANAGER=none ENABLE_SUSFS=false

assert_name \
  'AK3_marble_LOS_aosp-pablo_resukisu-v4.1.0-code34990_r9.zip' \
  KERNEL_SOURCE=aosp-pablo ROM_FAMILY=los \
  MANAGER=resukisu ENABLE_SUSFS=false \
  manager_build_version_name=v4.1.0 manager_build_version_code=34990

assert_name \
  'AK3_marble_LOS_pa-gr_ksunext-v3.2.0-code33203_susfs-v2.2.0_r9.zip' \
  KERNEL_SOURCE=pa-gr ROM_FAMILY=los \
  MANAGER=kernelsu-next ENABLE_SUSFS=true \
  manager_build_version_name='v3.2.0' manager_build_version_code=33203 \
  susfs_reported_version=v2.2.0

echo "Kernel source preset tests passed"
