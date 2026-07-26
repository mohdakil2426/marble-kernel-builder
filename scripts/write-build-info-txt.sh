#!/usr/bin/env bash
# Compose kernel-source/release/build-info.txt: the flat key=value provenance
# record that the summaries, build-info.json, and release verification all read.
#
# Everything resolved earlier in the pipeline lands here, then the contents of
# release/resolved-refs.env are appended verbatim.
set -euo pipefail

# Resolved source metadata from the CI environment must beat the stock defaults
# in config/marble.env. Keep the same precedence when this script is invoked
# directly with release/kernel-source.env present.
declare -A caller=()
for _var in \
  KERNEL_SOURCE KERNEL_SOURCE_DISPLAY KERNEL_SOURCE_AUTHOR \
  SOURCE_REPO SOURCE_REF SUPPORTED_ROM_LABEL ROM_FAMILY ROM_SUPPORT \
  DEFCONFIG_MODE DEFCONFIG BASE_DEFCONFIG CONFIG_FRAGMENTS \
  RECOMMENDED_TOOLCHAIN PACKAGE_FAMILY
do
  [[ -v "${_var}" ]] && caller["${_var}"]="${!_var}"
done
unset _var

source config/marble.env

KERNEL_SOURCE_ENV="${KERNEL_SOURCE_ENV:-release/kernel-source.env}"
if [[ -f "${KERNEL_SOURCE_ENV}" ]]; then
  # shellcheck disable=SC1090
  source "${KERNEL_SOURCE_ENV}"
fi

for _var in "${!caller[@]}"; do
  printf -v "${_var}" '%s' "${caller[${_var}]}"
done
unset _var

KERNEL_DIR="${KERNEL_DIR:-kernel-source}"
RESOLVED_REFS_FILE="${RESOLVED_REFS_FILE:-release/resolved-refs.env}"
release_dir="${KERNEL_DIR}/${RELEASE_DIR}"
build_info="${release_dir}/build-info.txt"

if [[ ! -f "${RESOLVED_REFS_FILE}" ]]; then
  echo "::error::Missing ${RESOLVED_REFS_FILE}; run resolve-refs.sh first"
  exit 1
fi

mkdir -p "${release_dir}"
cp "${RESOLVED_REFS_FILE}" "${release_dir}/resolved-refs.env"

KERNEL_SOURCE="${KERNEL_SOURCE:-melt}"
source_commit="$(git -C "${KERNEL_DIR}" rev-parse HEAD 2>/dev/null || echo unknown)"

if [[ "${KERNEL_SOURCE}" == "melt" ]]; then
  quality_label="melt-stable-candidate"
else
  quality_label="los-experimental"
fi

# resolved-refs.env carries only the numeric epoch, because package-anykernel.sh
# `source`s that file and the formatted stamp contains spaces. Format it here.
source_date_epoch="$(sed -n 's/^source_date_epoch=//p' "${RESOLVED_REFS_FILE}" | tail -n1)"
kbuild_timestamp=""
if [[ "${source_date_epoch}" =~ ^[0-9]+$ ]]; then
  kbuild_timestamp="$(date -u -d "@${source_date_epoch}" '+%a %b %d %H:%M:%S UTC %Y')"
fi

{
  echo "kernel_source=${KERNEL_SOURCE}"
  echo "kernel_source_display=${KERNEL_SOURCE_DISPLAY:-}"
  echo "kernel_source_author=${KERNEL_SOURCE_AUTHOR:-}"
  echo "rom_family=${ROM_FAMILY:-}"
  echo "rom_support=${ROM_SUPPORT:-}"
  echo "supported_rom_label=${SUPPORTED_ROM_LABEL:-}"
  echo "defconfig_mode=${DEFCONFIG_MODE:-}"
  echo "defconfig=${DEFCONFIG:-}"
  echo "base_defconfig=${BASE_DEFCONFIG:-}"
  echo "config_fragments=${CONFIG_FRAGMENTS:-}"
  echo "source_repo=${SOURCE_REPO:-}"
  echo "source_ref=${SOURCE_REF:-}"
  echo "source_commit=${source_commit}"
  echo "build_scope=${BUILD_SCOPE:-image-only}"
  echo "workflow_run=${GITHUB_SERVER_URL:-}/${GITHUB_REPOSITORY:-}/actions/runs/${GITHUB_RUN_ID:-}"
  echo "build_started_utc=${BUILD_STARTED_UTC:-$(date -u '+%Y-%m-%d %H:%M:%S UTC')}"
  echo "kbuild_build_timestamp=${kbuild_timestamp}"
  echo "runner_image_os=${ImageOS:-unknown}"
  echo "runner_image_version=${ImageVersion:-unknown}"
  echo "android_clang_version=${ACTIVE_TOOLCHAIN_VERSION:-}"
  echo "android_clang_commit=${ACTIVE_TOOLCHAIN_COMMIT:-}"
  echo "toolchain=${TOOLCHAIN:-}"
  echo "toolchain_digest=${ACTIVE_TOOLCHAIN_DIGEST:-}"
  echo "lto=${LTO:-thin}"
  echo "package_family=${PACKAGE_FAMILY:-}"
  echo "quality_channel=${QUALITY_CHANNEL:-experimental}"
  echo "quality_label=${quality_label}"
  echo "ccache_key=${CCACHE_KEY:-}"
  echo "ccache_hit=${CCACHE_HIT:-false}"
  echo "thinlto_cache_key=${THINLTO_KEY:-}"
  echo "thinlto_cache_hit=${THINLTO_HIT:-false}"
  echo "cache_writer=${CACHE_WRITER:-false}"
  echo "disk_available_before_build_gib=${DISK_AVAILABLE_GIB:-}"
  cat "${release_dir}/resolved-refs.env"
} > "${build_info}"

echo "Wrote ${build_info}"
