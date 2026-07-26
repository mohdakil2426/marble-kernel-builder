#!/usr/bin/env bash
set -euo pipefail

source config/marble.env

KERNEL_DIR="${KERNEL_DIR:-kernel-source}"
BUILD_SCOPE="${BUILD_SCOPE:-image-only}"
MANAGER="${MANAGER:-none}"
ENABLE_SUSFS="${ENABLE_SUSFS:-false}"
JOBS="${JOBS:-$(nproc)}"
USE_CCACHE="${USE_CCACHE:-true}"
TOOLCHAIN="${TOOLCHAIN:-android-r416183b}"

# Free GitHub-hosted runners (~7 GiB) often OOM (exit 137) while linking vmlinux
# with LLVM 22 at full -j$(nproc). Cap parallelism for the heavy toolchain.
# Free defaults: LLVM JOBS<=2, THINLTO_JOBS=2 (see ThinLTO wrapper below).
# Self-hosted override examples:
#   JOBS_FORCE=1 JOBS=8 THINLTO_JOBS=4
if [[ -z "${JOBS_FORCE:-}" ]]; then
  if [[ "${TOOLCHAIN}" == "llvm-22.1.8" ]] && (( JOBS > 2 )); then
    echo "Capping JOBS from ${JOBS} to 2 for ${TOOLCHAIN} (OOM-safe on free runners)"
    JOBS=2
  fi
fi

pushd "${KERNEL_DIR}" >/dev/null
mkdir -p "${OUT_DIR}" "${RELEASE_DIR}"

export ARCH
export SUBARCH="${ARCH}"
export KBUILD_BUILD_USER="${KBUILD_BUILD_USER:-marble}"
export KBUILD_BUILD_HOST="${KBUILD_BUILD_HOST:-github-actions}"
export CCACHE_DIR="${CCACHE_DIR:-${HOME}/.ccache}"
export CCACHE_COMPILERCHECK=content
export CCACHE_NOHASHDIR=true

if [[ -n "${ANDROID_CLANG_BIN:-}" ]]; then
  if [[ ! -x "${ANDROID_CLANG_BIN}/clang" ]]; then
    echo "::error::ANDROID_CLANG_BIN does not contain clang: ${ANDROID_CLANG_BIN}"
    exit 1
  fi
  export PATH="${ANDROID_CLANG_BIN}:${PATH}"
fi

if [[ "${USE_CCACHE}" == "true" ]] && command -v ccache >/dev/null 2>&1; then
  export CC="ccache clang"
  # LLVM 22 + LOS trees are heavier; allow a larger object cache when that toolchain is selected.
  if [[ "${TOOLCHAIN}" == "llvm-22.1.8" ]]; then
    ccache -M 6G
  else
    ccache -M 4G
  fi
  ccache -o compression=true
  # compression_level is supported on modern ccache; ignore if unavailable.
  ccache -o compression_level=6 2>/dev/null || true
  ccache -z || true
else
  export CC="clang"
fi

clang --version | tee "${RELEASE_DIR}/build.log"

DEFCONFIG_MODE="${DEFCONFIG_MODE:-single}"
case "${DEFCONFIG_MODE}" in
  single)
    active_defconfig="${DEFCONFIG:-marble_defconfig}"
    echo "Using single defconfig: ${active_defconfig}" | tee -a "${RELEASE_DIR}/build.log"
    make O="${OUT_DIR}" ARCH="${ARCH}" LLVM=1 LLVM_IAS=1 CC="${CC}" "${active_defconfig}" 2>&1 | tee -a "${RELEASE_DIR}/build.log"
    ;;
  gki_fragments)
    base_defconfig="${BASE_DEFCONFIG:-gki_defconfig}"
    echo "Using GKI base defconfig: ${base_defconfig}" | tee -a "${RELEASE_DIR}/build.log"
    make O="${OUT_DIR}" ARCH="${ARCH}" LLVM=1 LLVM_IAS=1 CC="${CC}" "${base_defconfig}" 2>&1 | tee -a "${RELEASE_DIR}/build.log"

    if [[ -z "${CONFIG_FRAGMENTS:-}" ]]; then
      echo "::error::DEFCONFIG_MODE=gki_fragments requires CONFIG_FRAGMENTS"
      exit 1
    fi

    fragment_paths=()
    # shellcheck disable=SC2206
    fragment_list=(${CONFIG_FRAGMENTS})
    for fragment in "${fragment_list[@]}"; do
      fragment_path="arch/${ARCH}/configs/${fragment}"
      if [[ ! -f "${fragment_path}" ]]; then
        echo "::error::Missing config fragment: ${fragment_path}"
        exit 1
      fi
      fragment_paths+=("${fragment_path}")
      echo "  + fragment ${fragment_path}" | tee -a "${RELEASE_DIR}/build.log"
    done

    if [[ ! -x scripts/kconfig/merge_config.sh ]]; then
      echo "::error::scripts/kconfig/merge_config.sh is missing or not executable"
      exit 1
    fi
    ./scripts/kconfig/merge_config.sh -O "${OUT_DIR}" -m "${OUT_DIR}/.config" "${fragment_paths[@]}" 2>&1 | tee -a "${RELEASE_DIR}/build.log"
    ;;
  *)
    echo "::error::Unsupported DEFCONFIG_MODE: ${DEFCONFIG_MODE}"
    exit 1
    ;;
esac

if [[ "${MANAGER}" != "none" ]]; then
  scripts/config --file "${OUT_DIR}/.config" -e KSU
fi
if [[ "${ENABLE_SUSFS}" == "true" ]]; then
  scripts/config --file "${OUT_DIR}/.config" -e KSU_SUSFS
fi

# Apply selectable Clang LTO for all presets (including gki_fragments / Melt).
# Default thin is free-runner safe with swap + thinlto job caps; full needs more RAM.
LTO="${LTO:-thin}"
echo "Applying LTO mode: ${LTO}" | tee -a "${RELEASE_DIR}/build.log"
case "${LTO}" in
  none)
    scripts/config --file "${OUT_DIR}/.config" \
      -d LTO_CLANG -d LTO_CLANG_THIN -d LTO_CLANG_FULL -e LTO_NONE || true
    # Also clear common Android synonyms if present
    scripts/config --file "${OUT_DIR}/.config" -e LTO_CLANG_NONE 2>/dev/null || true
    ;;
  thin)
    scripts/config --file "${OUT_DIR}/.config" \
      -d LTO_NONE -d LTO_CLANG_NONE -d LTO_CLANG_FULL -e LTO_CLANG -e LTO_CLANG_THIN || true
    ;;
  full)
    scripts/config --file "${OUT_DIR}/.config" \
      -d LTO_NONE -d LTO_CLANG_NONE -d LTO_CLANG_THIN -e LTO_CLANG -e LTO_CLANG_FULL || true
    echo "::warning::LTO=full is memory-heavy on free GitHub runners; prefer thin unless on high-RAM hosts"
    ;;
  *)
    echo "::error::Unsupported LTO=${LTO}"
    exit 1
    ;;
esac

make O="${OUT_DIR}" ARCH="${ARCH}" LLVM=1 LLVM_IAS=1 CC="${CC}" olddefconfig 2>&1 | tee -a "${RELEASE_DIR}/build.log"

if [[ "${MANAGER}" != "none" ]] && ! grep -q '^CONFIG_KSU=y$' "${OUT_DIR}/.config"; then
  echo "::error::CONFIG_KSU is not enabled in the final kernel config"
  exit 1
fi
if [[ "${ENABLE_SUSFS}" == "true" ]] && ! grep -q '^CONFIG_KSU_SUSFS=y$' "${OUT_DIR}/.config"; then
  echo "::error::CONFIG_KSU_SUSFS is not enabled in the final kernel config"
  exit 1
fi

targets=(Image)
if [[ "${BUILD_SCOPE}" == "full" ]]; then
  targets+=(modules dtbs)
fi

if [[ "${LTO}" == "thin" ]]; then
  # Cap ThinLTO parallel codegen on free runners (~7 GiB) to avoid OOM during link.
  THINLTO_JOBS="${THINLTO_JOBS:-2}"
  # WildKernels-style durable ThinLTO cache (restored/saved by the workflow when present).
  THINLTO_CACHE_DIR="${THINLTO_CACHE_DIR:-${HOME}/.cache/thinlto}"
  mkdir -p "${THINLTO_CACHE_DIR}"
  wrapper="$(pwd)/${RELEASE_DIR}/ld-thinlto-wrapper"
  {
    printf '#!/bin/bash\n'
    printf 'exec ld.lld "$@" --thinlto-jobs=%s --thinlto-cache-dir=%q\n' \
      "${THINLTO_JOBS}" "${THINLTO_CACHE_DIR}"
  } > "${wrapper}"
  chmod +x "${wrapper}"
  export LD="${wrapper}"
  export HOSTLD="${wrapper}"
  export THINLTO_CACHE_DIR
  echo "ThinLTO jobs=${THINLTO_JOBS} cache=${THINLTO_CACHE_DIR} via ${wrapper}" | tee -a "${RELEASE_DIR}/build.log"
fi

make -j"${JOBS}" O="${OUT_DIR}" ARCH="${ARCH}" LLVM=1 LLVM_IAS=1 CC="${CC}" "${targets[@]}" 2>&1 | tee -a "${RELEASE_DIR}/build.log"

image_path="${OUT_DIR}/arch/arm64/boot/Image"
if [[ ! -s "${image_path}" ]]; then
  echo "::error::Built Image not found at ${image_path}"
  exit 1
fi

image_size="$(stat -c%s "${image_path}")"
if [[ "${image_size}" -lt 5000000 ]]; then
  echo "::error::Built Image is unexpectedly small: ${image_size} bytes"
  exit 1
fi

if command -v file >/dev/null 2>&1; then
  file "${image_path}" | tee -a "${RELEASE_DIR}/build.log"
fi

cp "${image_path}" "${RELEASE_DIR}/Image"
for file in System.map vmlinux; do
  if [[ -s "${OUT_DIR}/${file}" ]]; then
    cp "${OUT_DIR}/${file}" "${RELEASE_DIR}/${file}"
  fi
done

if [[ "${BUILD_SCOPE}" == "full" ]]; then
  if find "${OUT_DIR}/arch/arm64/boot/dts" -name '*.dtb' -print -quit | grep -q .; then
    find "${OUT_DIR}/arch/arm64/boot/dts" -name '*.dtb' -print0 | tar --null -T - -czf "${RELEASE_DIR}/dtbs.tar.gz"
  fi
  if find "${OUT_DIR}" -name '*.ko' -print -quit | grep -q .; then
    find "${OUT_DIR}" -name '*.ko' -print0 | tar --null -T - -czf "${RELEASE_DIR}/modules.tar.gz"
  fi
fi

if [[ "${USE_CCACHE}" == "true" ]] && command -v ccache >/dev/null 2>&1; then
  ccache -s | tee "${RELEASE_DIR}/ccache-stats.txt" || true
fi

popd >/dev/null
