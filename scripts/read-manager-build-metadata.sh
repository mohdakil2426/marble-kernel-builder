#!/usr/bin/env bash
set -euo pipefail

source config/marble.env

KERNEL_DIR="${KERNEL_DIR:-kernel-source}"
RESOLVED_REFS_FILE="${RESOLVED_REFS_FILE:-release/resolved-refs.env}"

release_dir="${KERNEL_DIR}/${RELEASE_DIR}"
build_log="${release_dir}/build.log"

mkdir -p "$(dirname "${RESOLVED_REFS_FILE}")"

if [[ ! -f "${build_log}" ]]; then
  echo "::warning::Build log not found at ${build_log}; manager build metadata will be empty"
  {
    echo "manager_build_version_code="
    echo "manager_build_version_name="
    echo "manager_build_tag="
    echo "manager_signature_size="
    echo "manager_signature_hash="
    echo "manager_supported_line="
  } >> "${RESOLVED_REFS_FILE}"
  exit 0
fi

awk '
  /-- (KernelSU|KernelSU-Next) version:[[:space:]]*[0-9]+/ && !code {
    match($0, /-- (KernelSU|KernelSU-Next) version:[[:space:]]*([0-9]+)/, m)
    code = m[2]
  }
  /-- SukiSU-Ultra version:[[:space:]]*[0-9]+/ && !code {
    match($0, /-- SukiSU-Ultra version:[[:space:]]*([0-9]+)[[:space:]]+\[([^]]+)\]/, m)
    code = m[1]
    if (!name) name = m[2]
  }
  /-- ReSukiSU version code:[[:space:]]*[0-9]+/ && !code {
    match($0, /-- ReSukiSU version code:[[:space:]]*([0-9]+)/, m)
    code = m[1]
  }
  /-- ReSukiSU version name:[[:space:]]*.+/ && !name {
    match($0, /-- ReSukiSU version name:[[:space:]]*(.+)/, m)
    name = m[1]
  }
  /-- KernelSU-Next tag:[[:space:]]*.+/ && !tag {
    match($0, /-- KernelSU-Next tag:[[:space:]]*(.+)/, m)
    tag = m[1]
  }
  /-- (KernelSU|KernelSU-Next) Manager signature size:[[:space:]]*[^[:space:]]+/ && !sig_sz {
    match($0, /-- (KernelSU|KernelSU-Next) Manager signature size:[[:space:]]*([^[:space:]]+)/, m)
    sig_sz = m[2]
  }
  /-- (KernelSU|KernelSU-Next) Manager signature hash:[[:space:]]*[0-9a-fA-F]+/ && !sig_h {
    match($0, /-- (KernelSU|KernelSU-Next) Manager signature hash:[[:space:]]*([0-9a-fA-F]+)/, m)
    sig_h = m[2]
  }
  /-- Supported Unofficial Manager:[[:space:]]*.+/ && !supp {
    match($0, /-- Supported Unofficial Manager:[[:space:]]*(.+)/, m)
    supp = m[1]
    gsub(/, /, ",", supp)
  }
  END {
    print "manager_build_version_code=" code
    print "manager_build_version_name=" name
    print "manager_build_tag=" tag
    print "manager_signature_size=" sig_sz
    print "manager_signature_hash=" sig_h
    print "manager_supported_line=" supp
  }
' "${build_log}" >> "${RESOLVED_REFS_FILE}"

source "${RESOLVED_REFS_FILE}"
if [[ -n "${manager_build_version_code}${manager_build_version_name}${manager_build_tag}" ]]; then
  echo "Manager build metadata: code=${manager_build_version_code:-unknown} name=${manager_build_version_name:-${manager_build_tag:-unknown}}"
else
  echo "::warning::Manager build metadata not found in ${build_log}"
fi
