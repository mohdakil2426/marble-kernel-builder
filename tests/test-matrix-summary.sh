#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

make_artifact() {
  local dir="$1"
  local manager="$2"
  local manager_repo="$3"
  local manager_ref="$4"
  local manager_commit="$5"
  local manager_tag="$6"
  local build_code="$7"
  local build_name="$8"
  local zip_name="$9"
  local zip_payload="${10}"

  mkdir -p "${dir}"
  printf '%s\n' "${zip_payload}" > "${dir}/${zip_name}"
  sha256sum "${dir}/${zip_name}" > "${dir}/${zip_name}.sha256"
  cat > "${dir}/zip-name.env" <<ENV
zip_name=${zip_name}
ENV
  cat > "${dir}/build-info.txt" <<INFO
source_repo=mohdakil2426/android_kernel_xiaomi_marble
source_ref=melt-rebase
source_commit=3673961d444b5e2b879be97a161241243d543bd2
workflow_run=https://github.com/mohdakil2426/marble-kernel-builder/actions/runs/1
runner_image_os=ubuntu24
runner_image_version=20260615.205.1
android_clang_version=clang-r416183b
android_clang_commit=6e3223f76384455acde43affde3df0ea9df66c0d
toolchain=android-r416183b
lto=thin
package_family=MELT
kernel_source=melt
kernel_source_author=Melt
rom_support=Official Xiaomi stock HyperOS only
ccache_hit=false
thinlto_cache_hit=false
ccache_key=marble-builder-ccache-v4-test-key
thinlto_cache_key=marble-builder-thinlto-v1-test-key
manager=${manager}
manager_repo=${manager_repo}
manager_ref=${manager_ref}
manager_commit=${manager_commit}
manager_tag=${manager_tag}
manager_version_code=
manager_build_version_code=${build_code}
manager_build_version_name=${build_name}
manager_build_tag=${manager_tag}
manager_signature_size=
manager_signature_hash=
manager_supported_line=
enable_susfs=true
susfs_version=v2.2.0
susfs_kernel_branch=gki-android12-5.10
susfs_ref=4003ecf2d01c6d13fa8edf6c4f2607365738dc3d
susfs_commit=4003ecf2d01c6d13fa8edf6c4f2607365738dc3d
susfs_reported_version=v2.2.0
susfs_url=https://gitlab.com/simonpunk/susfs4ksu/-/commit/4003ecf2d01c6d13fa8edf6c4f2607365738dc3d
INFO
}

make_artifact "${tmp_dir}/marble-kernelsu-next-susfs-image-only-r5" \
  kernelsu-next pershoot/KernelSU-Next dev-susfs 5a8a604a9078c2fbfb50e2b0cba87b3a6f4da1c2 v3.2.0 33201 '' \
  AK3_marble_MELT_melt_ksunext-v3.2.0-code33201_susfs-v2.2.0_r5.zip ksunext

make_artifact "${tmp_dir}/marble-sukisu-ultra-susfs-image-only-r5" \
  sukisu-ultra SukiSU-Ultra/SukiSU-Ultra builtin b88403d2561b6e00dff84a3c851e630c62f57fd0 '' 40813 'v4.1.3-b88403d2@HEAD' \
  AK3_marble_MELT_melt_sukisu-v4.1.3-b88403d2-code40813_susfs-v2.2.0_r5.zip sukisu

make_artifact "${tmp_dir}/marble-resukisu-susfs-image-only-r5" \
  resukisu ReSukiSU/ReSukiSU main 88e7f51c3840436b982276ec35bf2876cfec2713 '' 34989 'v4.1.0-d0f59d06@ReSukiSU' \
  AK3_marble_MELT_melt_resukisu-v4.1.0-d0f59d06-code34989_susfs-v2.2.0_r5.zip resukisu

mkdir -p "${tmp_dir}/unrelated-artifact-r5"
printf '%s\n' 'artifact without flash metadata' > "${tmp_dir}/unrelated-artifact-r5/build.log"

MATRIX_ARTIFACTS_DIR="${tmp_dir}" MATRIX_SUMMARY="${tmp_dir}/matrix-summary.md" \
  BUILD_SCOPE=image-only GITHUB_RUN_NUMBER=5 \
  bash scripts/generate-matrix-summary.sh >/dev/null

summary="${tmp_dir}/matrix-summary.md"

required_patterns=(
  '^# Marble Kernel · Matrix Build$'
  'marble-banner\.svg'
  'Before you flash'
  'Match \*\*device \+ ROM\*\*'
  '^## .*Matrix configuration$'
  '\| .*LTO.* \| `thin` \|'
  '\| .*Toolchain.* \| `android-r416183b` \|'
  '\| .*Package family.* \| `MELT` \|'
  'badge/LTO-thin'
  '^## .*Cache$'
  'marble-ci-cache-start'
  'Actions ccache'
  'GitHub Release notes'
  'ccache -s'
  'github.com/mohdakil2426/android_kernel_xiaomi_marble'
  '^## .*Managers$'
  '\| \*\*KernelSU-Next\*\* \| `v3\.2\.0` \| `33201` \|'
  '\| \*\*SukiSU Ultra\*\* \| `v4\.1\.3-b88403d2@HEAD` \| `40813` \|'
  '\| \*\*ReSukiSU\*\* \| `v4\.1\.0-d0f59d06@ReSukiSU` \| `34989` \|'
  '<summary><b>KernelSU-Next</b> — v3\.2\.0 · code 33201 · ✅ Passed</summary>'
  '<summary><b>SukiSU Ultra</b> — v4\.1\.3-b88403d2@HEAD · code 40813 · ✅ Passed</summary>'
  '<summary><b>ReSukiSU</b> — v4\.1\.0-d0f59d06@ReSukiSU · code 34989 · ✅ Passed</summary>'
  '^## .*SUSFS$'
  '^## .*Artifacts & checksums$'
  '^## .*Installation$'
  'AK3_marble_MELT_melt_ksunext-v3\.2\.0-code33201_susfs-v2\.2\.0_r5\.zip'
  'AK3_marble_MELT_melt_sukisu-v4\.1\.3-b88403d2-code40813_susfs-v2\.2\.0_r5\.zip'
  'AK3_marble_MELT_melt_resukisu-v4\.1\.0-d0f59d06-code34989_susfs-v2\.2\.0_r5\.zip'
  '^## .*Credits$'
  'pershoot/KernelSU-Next'
  'SukiSU-Ultra/SukiSU-Ultra'
  'ReSukiSU/ReSukiSU'
  'osm0sis/AnyKernel3'
  'Built with GitHub Actions · for Marble'
)

if grep -Eq 'Pzqqt' "${summary}"; then
  echo "FAIL: matrix summary must not hardcode Pzqqt in credits" >&2
  exit 1
fi

# SUSFS-on fixtures: module note OK. When enable_susfs is false, no module push.
if ! grep -Eq 'SUSFS userspace module|sidex15/susfs4ksu-module' "${summary}"; then
  echo "FAIL: matrix SUSFS-enabled fixtures should mention userspace module" >&2
  exit 1
fi

# Matrix summary may report ROM support from build-info, but must not hardcode only HyperOS wording
# when artifacts omit rom_support. Current fixtures include HyperOS packaging labels only.
if grep -Eq 'MIUI, AOSP, and custom ROMs are unsupported' "${summary}"; then
  echo "FAIL: matrix summary should not use the old single-build HyperOS-only install wording" >&2
  exit 1
fi

for pattern in "${required_patterns[@]}"; do
  if ! grep -Eq "${pattern}" "${summary}"; then
    echo "FAIL: matrix summary missing pattern: ${pattern}" >&2
    exit 1
  fi
done

# Cache section must not appear in release-stripped notes.
release_notes="${tmp_dir}/matrix-summary-release.md"
# shellcheck disable=SC1091
source scripts/lib/summary-common.sh
summary_strip_cache_section "${summary}" "${release_notes}"
if grep -Eq 'marble-ci-cache|Actions ccache' "${release_notes}"; then
  echo "FAIL: release notes still contain CI cache section" >&2
  exit 1
fi
if grep -Eq '^## .*Cache$' "${release_notes}"; then
  echo "FAIL: release notes still have Cache heading" >&2
  exit 1
fi
if ! grep -Eq 'Matrix configuration|Artifacts' "${release_notes}"; then
  echo "FAIL: release notes lost main content after cache strip" >&2
  exit 1
fi

if [[ "$(grep -cE '^## .*Installation$' "${summary}")" -ne 1 ]]; then
  echo "FAIL: matrix summary should contain one shared Installation section" >&2
  exit 1
fi

single_root="${tmp_dir}/single-root"
make_artifact "${single_root}" \
  kernelsu-next pershoot/KernelSU-Next dev-susfs 5a8a604a9078c2fbfb50e2b0cba87b3a6f4da1c2 v3.2.0 33201 '' \
  AK3_marble_MELT_melt_ksunext-v3.2.0-code33201_susfs-v2.2.0_r5.zip ksunext

MATRIX_ARTIFACTS_DIR="${single_root}" MATRIX_SUMMARY="${tmp_dir}/single-matrix-summary.md" \
  BUILD_SCOPE=image-only GITHUB_RUN_NUMBER=5 \
  bash scripts/generate-matrix-summary.sh >/dev/null

single_summary="${tmp_dir}/single-matrix-summary.md"
if ! grep -Eq '<summary><b>KernelSU-Next</b> — v3\.2\.0 · code 33201 · ✅ Passed</summary>' "${single_summary}"; then
  echo "FAIL: matrix summary should support one artifact extracted directly into the artifacts directory" >&2
  exit 1
fi

echo "Matrix summary tests passed"
