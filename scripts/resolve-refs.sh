#!/usr/bin/env bash
set -euo pipefail

source config/marble.env

MANAGER="${MANAGER:-none}"
MANAGER_REF="${MANAGER_REF:-}"
ENABLE_SUSFS="${ENABLE_SUSFS:-false}"
SUSFS_VERSION="${SUSFS_VERSION:-${SUSFS_VERSION_DEFAULT}}"
SUSFS_KERNEL_BRANCH="${SUSFS_KERNEL_BRANCH:-${SUSFS_KERNEL_BRANCH_DEFAULT}}"
SUSFS_REF="${SUSFS_REF:-}"
SUSFS_EXPECTED_VERSION="${SUSFS_EXPECTED_VERSION:-}"
KERNEL_DIR="${KERNEL_DIR:-kernel-source}"

mkdir -p release

source_commit="$(git -C "${KERNEL_DIR}" rev-parse HEAD)"
manager_repo=""
manager_effective_ref=""
manager_commit=""
manager_tag=""
manager_setup_path=""
susfs_effective_ref=""
susfs_commit=""
susfs_reported_version=""
susfs_url=""

if [[ "${MANAGER}" != "none" ]]; then
  manager_repo="$(jq -r --arg manager "${MANAGER}" '.[$manager].repo' config/managers.json)"
  manager_default_ref="$(jq -r --arg manager "${MANAGER}" '.[$manager].default_ref' config/managers.json)"
  if [[ "${ENABLE_SUSFS}" == "true" ]]; then
    manager_susfs_repo="$(jq -r --arg manager "${MANAGER}" '.[$manager].susfs_repo // empty' config/managers.json)"
    if [[ -n "${manager_susfs_repo}" ]]; then
      manager_repo="${manager_susfs_repo}"
    fi
    manager_default_ref="$(jq -r --arg manager "${MANAGER}" '.[$manager].susfs_ref' config/managers.json)"
  fi
  manager_effective_ref="${MANAGER_REF:-${manager_default_ref}}"
  manager_setup_path="$(jq -r --arg manager "${MANAGER}" '.[$manager].setup_path' config/managers.json)"

  if command -v gh >/dev/null 2>&1; then
    manager_commit="$(gh api "repos/${manager_repo}/commits/${manager_effective_ref}" --jq .sha)"
  else
    manager_commit="$(git ls-remote "https://github.com/${manager_repo}.git" \
      "refs/heads/${manager_effective_ref}" "refs/tags/${manager_effective_ref}^{}" "refs/tags/${manager_effective_ref}" |
      awk 'NR == 1 { print $1 }')"
    if [[ -z "${manager_commit}" && "${manager_effective_ref}" =~ ^[0-9a-fA-F]{40}$ ]]; then
      manager_commit="${manager_effective_ref}"
    fi
  fi
  if [[ -z "${manager_commit}" ]]; then
    echo "::error::Could not resolve official manager ref ${manager_repo}@${manager_effective_ref}"
    exit 1
  fi

  # Resolve the nearest git tag for this commit (for human-readable version display).
  # git ls-remote outputs both tag objects (no suffix) and dereferenced commits (^{} suffix).
  # We match the commit SHA against ^{} lines first (annotated tags), then plain lines (lightweight).
  all_tags="$(git ls-remote --tags "https://github.com/${manager_repo}.git" 2>/dev/null || true)"
  manager_tag="$(echo "${all_tags}" | awk -v sha="${manager_commit}" \
    '$1==sha && /\^\{\}$/ { sub(/.*refs\/tags\//, "", $2); sub(/\^\{\}/, "", $2); print; exit }')"
  if [[ -z "${manager_tag}" ]]; then
    manager_tag="$(echo "${all_tags}" | awk -v sha="${manager_commit}" \
      '$1==sha { sub(/.*refs\/tags\//, "", $2); print; exit }')"
  fi
fi

if [[ "${ENABLE_SUSFS}" == "true" ]]; then
  if [[ "${SUSFS_VERSION}" == "custom" ]]; then
    susfs_effective_ref="${SUSFS_REF}"
  else
    susfs_effective_ref="$(jq -r --arg branch "${SUSFS_KERNEL_BRANCH}" --arg version "${SUSFS_VERSION}" '.[$branch][$version].ref // empty' config/susfs-refs.json)"
    if [[ -z "${susfs_effective_ref}" ]]; then
      echo "::error::No SUSFS preset for ${SUSFS_KERNEL_BRANCH} ${SUSFS_VERSION}"
      exit 1
    fi
  fi

  # Shallow resolve of SUSFS version from simonpunk/susfs4ksu. Cleanup must never
  # fail this step: free runners occasionally race on partial-clone temp trees
  # (observed: `rm: cannot remove '...': Directory not empty` under set -e).
  tmp_susfs="$(mktemp -d)"
  cleanup_tmp_susfs() {
    local dir="${1:-}"
    [[ -n "${dir}" && -d "${dir}" ]] || return 0
    chmod -R u+w "${dir}" 2>/dev/null || true
    rm -rf "${dir}" 2>/dev/null || true
  }
  trap 'cleanup_tmp_susfs "${tmp_susfs}"' EXIT

  git clone --filter=blob:none --no-checkout "${SUSFS_REPO}" "${tmp_susfs}"
  git -C "${tmp_susfs}" checkout "${susfs_effective_ref}"
  susfs_commit="$(git -C "${tmp_susfs}" rev-parse HEAD)"
  susfs_reported_version="$(
    find "${tmp_susfs}/kernel_patches" -path '*/include/linux/susfs.h' -type f -print0 2>/dev/null |
      xargs -0 -r grep -hoE 'SUSFS_VERSION[[:space:]]+"v[0-9]+\.[0-9]+\.[0-9]+"' 2>/dev/null |
      head -n1 |
      sed -E 's/.*"(v[^"]+)".*/\1/' || true
  )"
  cleanup_tmp_susfs "${tmp_susfs}"
  trap - EXIT
  tmp_susfs=""

  # GitLab commit URL for traceability in release notes
  susfs_url="https://gitlab.com/simonpunk/susfs4ksu/-/commit/${susfs_commit}"

  expected="${SUSFS_EXPECTED_VERSION}"
  if [[ -z "${expected}" && "${SUSFS_VERSION}" != "custom" ]]; then
    expected="${SUSFS_VERSION}"
  fi
  if [[ -n "${expected}" && "${susfs_reported_version}" != "${expected}" ]]; then
    echo "::error::SUSFS version mismatch. Expected ${expected}, got ${susfs_reported_version:-unknown}"
    exit 1
  fi
fi

{
  echo "source_commit=${source_commit}"
  echo "manager=${MANAGER}"
  echo "manager_repo=${manager_repo}"
  echo "manager_ref=${manager_effective_ref}"
  echo "manager_commit=${manager_commit}"
  echo "manager_tag=${manager_tag}"
  echo "manager_setup_path=${manager_setup_path}"
  echo "enable_susfs=${ENABLE_SUSFS}"
  echo "susfs_version=${SUSFS_VERSION}"
  echo "susfs_kernel_branch=${SUSFS_KERNEL_BRANCH}"
  echo "susfs_ref=${susfs_effective_ref}"
  echo "susfs_commit=${susfs_commit}"
  echo "susfs_reported_version=${susfs_reported_version}"
  echo "susfs_url=${susfs_url}"
} | tee release/resolved-refs.env
