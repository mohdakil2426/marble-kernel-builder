#!/usr/bin/env bash
set -euo pipefail

source config/marble.env

KERNEL_DIR="${KERNEL_DIR:-kernel-source}"
release_dir="${KERNEL_DIR}/${RELEASE_DIR}"
build_info="${release_dir}/build-info.txt"
zip_env="${release_dir}/zip-name.env"
json_file="${release_dir}/build-info.json"

if [[ ! -f "${build_info}" || ! -f "${zip_env}" ]]; then
  echo "::error::Missing build-info.txt or zip-name.env for JSON metadata"
  exit 1
fi

python3 - "${build_info}" "${zip_env}" "${json_file}" <<'PY'
import json
import sys
from pathlib import Path


def read_kv(path):
    values = {}
    for raw in Path(path).read_text(encoding="utf-8").splitlines():
        if not raw or raw.lstrip().startswith("#") or "=" not in raw:
            continue
        key, value = raw.split("=", 1)
        values[key] = value
    return values


info = read_kv(sys.argv[1])
zip_info = read_kv(sys.argv[2])

supported = [
    item.strip()
    for item in info.get("manager_supported_line", "").split(",")
    if item.strip()
]

data = {
    "source": {
        "repo": info.get("source_repo", ""),
        "ref": info.get("source_ref", ""),
        "commit": info.get("source_commit", ""),
    },
    "workflow": {
        "run": info.get("workflow_run", ""),
        "runner_image_os": info.get("runner_image_os", ""),
        "runner_image_version": info.get("runner_image_version", ""),
    },
    "compiler": {
        "android_clang_version": info.get("android_clang_version", ""),
        "android_clang_commit": info.get("android_clang_commit", ""),
    },
    "cache": {
        "ccache_key": info.get("ccache_key", ""),
        "ccache_hit": info.get("ccache_hit", ""),
        "thinlto_cache_key": info.get("thinlto_cache_key", ""),
        "thinlto_cache_hit": info.get("thinlto_cache_hit", ""),
    },
    "build": {
        "lto": info.get("lto", ""),
        "toolchain": info.get("toolchain", ""),
        "package_family": info.get("package_family", ""),
        "quality_channel": info.get("quality_channel", ""),
        "quality_label": info.get("quality_label", ""),
        "scope": info.get("build_scope", ""),
    },
    "manager": {
        "name": info.get("manager", ""),
        "repo": info.get("manager_repo", ""),
        "ref": info.get("manager_ref", ""),
        "commit": info.get("manager_commit", ""),
        "tag": info.get("manager_tag", ""),
        "version_code": info.get("manager_version_code", ""),
        "setup_path": info.get("manager_setup_path", ""),
        "build": {
            "version_code": info.get("manager_build_version_code", ""),
            "version_name": info.get("manager_build_version_name", ""),
            "tag": info.get("manager_build_tag", ""),
            "signature_size": info.get("manager_signature_size", ""),
            "signature_hash": info.get("manager_signature_hash", ""),
            "supported": supported,
        },
    },
    "susfs": {
        "enabled": info.get("enable_susfs", "false") == "true",
        "version": info.get("susfs_version", ""),
        "kernel_branch": info.get("susfs_kernel_branch", ""),
        "ref": info.get("susfs_ref", ""),
        "commit": info.get("susfs_commit", ""),
        "reported_version": info.get("susfs_reported_version", ""),
        "url": info.get("susfs_url", ""),
    },
    "artifact": {
        "zip_name": zip_info.get("zip_name", ""),
        "zip_sha256": zip_info.get("zip_sha256", ""),
    },
}

Path(sys.argv[3]).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

echo "Wrote ${json_file}"
