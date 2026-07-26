#!/usr/bin/env bash
set -euo pipefail

MANAGER="${MANAGER:-none}"
KERNEL_DIR="${KERNEL_DIR:-kernel-source}"

if [[ "${MANAGER}" == "none" ]]; then
  echo "No manager selected"
  exit 0
fi

source release/resolved-refs.env

if [[ -z "${manager_repo}" || -z "${manager_commit}" || -z "${manager_setup_path}" ]]; then
  echo "::error::Manager resolution missing repo, commit, or setup path"
  exit 1
fi

pushd "${KERNEL_DIR}" >/dev/null
setup_url="https://raw.githubusercontent.com/${manager_repo}/${manager_commit}/${manager_setup_path}"
echo "Applying ${MANAGER} from ${manager_repo}@${manager_commit}"
curl -fsSL "${setup_url}" -o /tmp/manager-setup.sh

bash /tmp/manager-setup.sh "${manager_commit}"
popd >/dev/null
