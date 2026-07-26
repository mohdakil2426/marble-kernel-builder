#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

release_dir="${tmp_dir}/release"
mkdir -p "${release_dir}"
cat > "${release_dir}/build-info.txt" <<'INFO'
source_repo=mohdakil2426/android_kernel_xiaomi_marble
source_ref=melt-rebase
source_commit=3673961d444b5e2b879be97a161241243d543bd2
manager=resukisu
manager_repo=ReSukiSU/ReSukiSU
manager_ref=main
manager_commit=88e7f51c3840436b982276ec35bf2876cfec2713
manager_build_version_code=34990
manager_build_version_name=v4.1.0-88e7f51c@ReSukiSU
manager_supported_line=MKSU,RKSU,KOWSU,SukiSU-Ultra,ReSukiSU
enable_susfs=true
susfs_reported_version=v2.2.0
INFO
cat > "${release_dir}/zip-name.env" <<'ENV'
zip_name=AK3_marble_MELT_melt_resukisu-v4.1.0-code34990_susfs-v2.2.0_r7.zip
zip_sha256=abc123
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

assert data["source"]["repo"] == "mohdakil2426/android_kernel_xiaomi_marble"
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
assert data["susfs"]["enabled"] is True
assert data["susfs"]["reported_version"] == "v2.2.0"
assert data["artifact"]["zip_name"].startswith("AK3_marble_MELT_melt_resukisu")
assert data["artifact"]["zip_sha256"] == "abc123"
PY

echo "Build-info JSON tests passed"
