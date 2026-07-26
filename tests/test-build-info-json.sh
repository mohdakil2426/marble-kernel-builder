#!/usr/bin/env bash
# Exercises the real producers end to end: resolved-refs.env → build-info.txt →
# build-info.json. Driving the actual writer rather than a hand-written fixture
# keeps the two from drifting apart.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

tmp_dir="$(mktemp -d)"
refs_file="${tmp_dir}/resolved-refs.env"
trap 'rm -rf "${tmp_dir}"' EXIT

release_dir="${tmp_dir}/release"
mkdir -p "${release_dir}"

# What resolve-refs.sh, patch-manager.sh, read-manager-*.sh and build-kernel.sh
# append during a real run. Every value here must be `source`-safe, because
# package-anykernel.sh sources this file after the build.
cat > "${refs_file}" <<'REFS'
source_commit=3673961d444b5e2b879be97a161241243d543bd2
manager=resukisu
manager_repo=ReSukiSU/ReSukiSU
manager_ref=main
manager_commit=88e7f51c3840436b982276ec35bf2876cfec2713
manager_tag=
manager_setup_path=kernel/setup.sh
manager_setup_sha256=9f2c1b7d5e4a3c88f0b6d21e7a45c93b8de10f6742ab5c39d8e0741bc2a6f358
manager_build_version_code=34990
manager_build_version_name=v4.1.0-88e7f51c@ReSukiSU
manager_supported_line=MKSU,RKSU,KOWSU,SukiSU-Ultra,ReSukiSU
enable_susfs=true
susfs_version=v2.2.0
susfs_kernel_branch=gki-android12-5.10
susfs_commit=4003ecf2d01c6d13fa8edf6c4f2607365738dc3d
susfs_reported_version=v2.2.0
source_date_epoch=1784000539
ccache_hit_rate=91.4%
ccache_direct_rate=88.2%
REFS

# Nothing appended after resolve-refs may break `source`, or packaging dies.
# (This is why the formatted KBUILD timestamp is derived later, not stored here.)
if ! ( set -euo pipefail; source "${refs_file}" ) >/dev/null 2>&1; then
  echo "FAIL: resolved-refs.env is not source-safe" >&2
  exit 1
fi

KERNEL_DIR="${tmp_dir}" RESOLVED_REFS_FILE="${refs_file}" \
  KERNEL_SOURCE=evolution-x KERNEL_SOURCE_DISPLAY=Evolution-X \
  KERNEL_SOURCE_AUTHOR=Evolution-X SUPPORTED_ROM_LABEL=Evolution-X \
  ROM_FAMILY=los ROM_SUPPORT='Evolution X and LOS-based custom ROMs only' \
  DEFCONFIG_MODE=gki_fragments DEFCONFIG='' BASE_DEFCONFIG=gki_defconfig \
  CONFIG_FRAGMENTS='vendor/waipio_GKI.config vendor/xiaomi_GKI.config vendor/marble_GKI.config vendor/debugfs.config' \
  SOURCE_REPO=Evolution-X-Devices/kernel_xiaomi_sm8450 SOURCE_REF=cnb \
  BUILD_SCOPE=image-only LTO=thin TOOLCHAIN=llvm-22.1.8 PACKAGE_FAMILY=LOS \
  CCACHE_KEY=marble-ccache-v5-test CCACHE_HIT=true \
  THINLTO_KEY=marble-thinlto-v5-test THINLTO_HIT=true CACHE_WRITER=true \
  BUILD_STARTED_UTC='2026-07-26 09:14:02 UTC' \
  bash scripts/write-build-info-txt.sh >/dev/null

build_info="${release_dir}/build-info.txt"
[[ -f "${build_info}" ]] || {
  echo "FAIL: build-info.txt was not created" >&2
  exit 1
}
grep -Fxq 'supported_rom_label=Evolution-X' "${build_info}" || {
  echo "FAIL: build-info.txt replaced the resolved Evolution-X ROM label" >&2
  exit 1
}
grep -Fxq 'rom_family=los' "${build_info}" || {
  echo "FAIL: build-info.txt lost the resolved LOS ROM family" >&2
  exit 1
}
grep -Fxq 'defconfig=' "${build_info}" || {
  echo "FAIL: build-info.txt replaced the resolved fragment config with the stock defconfig" >&2
  exit 1
}
grep -Fxq 'base_defconfig=gki_defconfig' "${build_info}" || {
  echo "FAIL: build-info.txt lost the resolved LOS base defconfig" >&2
  exit 1
}

cat > "${release_dir}/zip-name.env" <<'ENV'
zip_name=AK3_marble_LOS_evolution-x_resukisu-v4.1.0-code34990_susfs-v2.2.0_r7.zip
zip_sha256=abc123
zip_size_bytes=31457280
ENV

KERNEL_DIR="${tmp_dir}" bash scripts/write-build-info-json.sh >/dev/null

json_file="${release_dir}/build-info.json"
[[ -f "${json_file}" ]] || {
  echo "FAIL: build-info.json was not created" >&2
  exit 1
}

python3 - "${json_file}" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)

assert data["source"]["repo"] == "Evolution-X-Devices/kernel_xiaomi_sm8450"
assert data["source"]["ref"] == "cnb"

assert data["manager"]["name"] == "resukisu"
assert data["manager"]["build"]["version_code"] == "34990"
assert data["manager"]["build"]["version_name"] == "v4.1.0-88e7f51c@ReSukiSU"
assert data["manager"]["build"]["supported"] == [
    "MKSU",
    "RKSU",
    "KOWSU",
    "SukiSU-Ultra",
    "ReSukiSU",
]
# Provenance for the remote script that was actually executed.
assert data["manager"]["setup_sha256"].startswith("9f2c1b7d")

assert data["susfs"]["enabled"] is True
assert data["susfs"]["reported_version"] == "v2.2.0"

assert data["artifact"]["zip_name"].startswith("AK3_marble_LOS_evolution-x_resukisu")
assert data["artifact"]["zip_sha256"] == "abc123"
assert data["artifact"]["zip_size_bytes"] == "31457280"

assert data["build"]["scope"] == "image-only"
assert data["build"]["lto"] == "thin"
assert data["build"]["toolchain"] == "llvm-22.1.8"
assert data["build"]["package_family"] == "LOS"
assert data["build"]["started_utc"] == "2026-07-26 09:14:02 UTC"
# Reproducibility: the kernel timestamp is derived from the source commit epoch
# and is distinct from the CI clock above.
assert data["build"]["source_date_epoch"] == "1784000539"
assert "UTC" in data["build"]["kbuild_build_timestamp"], "kbuild timestamp must derive from the epoch"

# Cache effectiveness must be readable from metadata alone.
assert data["cache"]["ccache_hit"] == "true"
assert data["cache"]["ccache_hit_rate"] == "91.4%"
assert data["cache"]["ccache_direct_rate"] == "88.2%"
assert data["cache"]["writer"] is True
PY

echo "Build-info JSON tests passed"
