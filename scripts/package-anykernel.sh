#!/usr/bin/env bash
set -euo pipefail

_caller_source="${KERNEL_SOURCE:-}"
_caller_rom="${ROM_FAMILY:-}"
_caller_pkg="${PACKAGE_FAMILY:-}"

source config/marble.env

if [[ -f release/resolved-refs.env ]]; then
  # shellcheck disable=SC1091
  source release/resolved-refs.env
fi
if [[ -f release/kernel-source.env ]]; then
  # shellcheck disable=SC1091
  source release/kernel-source.env
fi

KERNEL_SOURCE="${_caller_source:-${KERNEL_SOURCE:-melt}}"
ROM_FAMILY="${_caller_rom:-${ROM_FAMILY:-}}"
KERNEL_DIR="${KERNEL_DIR:-kernel-source}"
MANAGER="${MANAGER:-none}"
ENABLE_SUSFS="${ENABLE_SUSFS:-false}"
BUILD_SCOPE="${BUILD_SCOPE:-image-only}"
run_number="${GITHUB_RUN_NUMBER:-local}"
LTO="${LTO:-thin}"
SUPPORTED_ROM_LABEL="${SUPPORTED_ROM_LABEL:-HyperOS}"
sanitize_token() {
  printf '%s' "$1" | sed -E 's/[^A-Za-z0-9._-]+/-/g; s/^-+//; s/-+$//'
}

case "${PACKAGE_FAMILY:-${ROM_FAMILY:-${KERNEL_SOURCE}}}" in
  LOS|los|lineageos|evolution-x|aosp-pablo|pa-gr) PACKAGE_FAMILY="LOS" ;;
  *) PACKAGE_FAMILY="MELT" ;;
esac
source_token="$(sanitize_token "${KERNEL_SOURCE:-melt}")"
[[ -n "${source_token}" ]] || source_token="melt"

case "${MANAGER}" in
  none)          manager_token="noroot" ;;
  kernelsu)      manager_token="kernelsu" ;;
  kernelsu-next) manager_token="ksunext" ;;
  sukisu-ultra)  manager_token="sukisu" ;;
  resukisu)      manager_token="resukisu" ;;
  *)             manager_token="$(sanitize_token "${MANAGER}")" ;;
esac

# Prefer the version printed by the manager build, then its resolved tag, then commit.
manager_version="${manager_build_version_name:-${manager_build_tag:-${manager_tag:-}}}"
manager_version="${manager_version%%@*}"
if [[ -z "${manager_version}" && -n "${manager_commit:-}" ]]; then
  manager_version="${manager_commit:0:7}"
fi
manager_version="$(sanitize_token "${manager_version}")"

manager_code="${manager_build_version_code:-${manager_version_code:-}}"
if [[ ! "${manager_code}" =~ ^[0-9]+$ ]]; then
  manager_code=""
fi

if [[ "${MANAGER}" == "none" ]]; then
  manager_identity="noroot"
else
  manager_identity="${manager_token}"
  if [[ -n "${manager_version}" ]]; then
    manager_identity+="-${manager_version}"
  fi
  if [[ -n "${manager_code}" ]]; then
    manager_identity+="-code${manager_code}"
  fi
fi

susfs_segment=""
if [[ "${ENABLE_SUSFS}" == "true" ]]; then
  susfs_ver="$(sanitize_token "${susfs_reported_version:-${SUSFS_VERSION:-unknown}}")"
  susfs_segment="_susfs-${susfs_ver}"
fi

# Locked format:
# AK3_marble_<FAMILY>_<source>_<manager>[-version][-codeN][_susfs-vX.Y.Z]_rN.zip
zip_name="AK3_marble_${PACKAGE_FAMILY}_${source_token}_${manager_identity}${susfs_segment}_r${run_number}.zip"

generate_banner_text() {
  local family source_line manager_line susfs_line lto_line
  family="${PACKAGE_FAMILY}"
  source_line="${KERNEL_SOURCE:-melt}"
  lto_line="${LTO:-thin}"

  if [[ "${MANAGER}" == "none" ]]; then
    manager_line="noroot"
  else
    manager_line="${manager_token}"
    if [[ -n "${manager_version}" ]]; then
      manager_line+=" ${manager_version}"
    fi
    if [[ -n "${manager_code}" ]]; then
      manager_line+=" (code ${manager_code})"
    fi
  fi

  if [[ "${ENABLE_SUSFS}" == "true" ]]; then
    susfs_line="${susfs_reported_version:-${SUSFS_VERSION:-enabled}}"
  else
    susfs_line="disabled"
  fi

  cat <<EOF
Marble Kernel
────────────────────────────────────────
Device   : Poco F5 / Redmi Note 12 Turbo
Codename : marble | marblein
Family   : ${family}
Source   : ${source_line}
Manager  : ${manager_line}
SUSFS    : ${susfs_line}
LTO      : ${lto_line}
Run      : r${run_number}
────────────────────────────────────────
Flash only matching ROM family.
Backup boot is created before flash.
EOF
}

if [[ "${PACKAGE_NAME_ONLY:-false}" == "true" ]]; then
  printf '%s\n' "${zip_name}"
  exit 0
fi

if [[ "${PACKAGE_BANNER_ONLY:-false}" == "true" ]]; then
  generate_banner_text
  exit 0
fi

image_path="${release_dir}/Image"
if [[ ! -s "${image_path}" ]]; then
  echo "::error::Cannot package without ${image_path}"
  exit 1
fi

work_dir="$(mktemp -d)"
git init -q "${work_dir}/ak3"
git -C "${work_dir}/ak3" remote add origin "${ANYKERNEL3_REPO}"
git -C "${work_dir}/ak3" fetch --depth=1 origin "${ANYKERNEL3_REF}"
git -C "${work_dir}/ak3" checkout -q --detach FETCH_HEAD
anykernel3_commit="$(git -C "${work_dir}/ak3" rev-parse HEAD)"
echo "anykernel3_commit=${anykernel3_commit}" >> release/resolved-refs.env
rsync -a ak3/ "${work_dir}/ak3/"
generate_banner_text > "${work_dir}/ak3/banner"
cp "${image_path}" "${work_dir}/ak3/Image"

pushd "${work_dir}/ak3" >/dev/null
zip -r9 "${OLDPWD}/${release_dir}/${zip_name}" . -x ".git/*" "README.md" "*placeholder*"
popd >/dev/null

pushd "${release_dir}" >/dev/null
sha256sum "${zip_name}" > "${zip_name}.sha256"
printf 'zip_name=%s\n' "${zip_name}" > zip-name.env
printf 'zip_sha256=%s\n' "$(sha256sum "${zip_name}" | awk '{print $1}')" >> zip-name.env
printf 'package_family=%s\n' "${PACKAGE_FAMILY}" >> zip-name.env
popd >/dev/null

rm -rf "${work_dir}"
echo "Packaged ${release_dir}/${zip_name}"
