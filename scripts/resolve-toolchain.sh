#!/usr/bin/env bash
set -euo pipefail

# Resolve TOOLCHAIN=auto from kernel preset recommended_toolchain.
# Prefer an explicit KERNEL_SOURCE over any stale release/kernel-source.env.

if [[ -n "${KERNEL_SOURCE:-}" ]]; then
  SOURCE_REF="${SOURCE_REF:-}"
  bash scripts/resolve-kernel-source.sh >/dev/null
elif [[ -f release/kernel-source.env ]]; then
  # shellcheck disable=SC1091
  source release/kernel-source.env
else
  KERNEL_SOURCE=melt
  SOURCE_REF="${SOURCE_REF:-}"
  bash scripts/resolve-kernel-source.sh >/dev/null
fi

if [[ -f release/kernel-source.env ]]; then
  # shellcheck disable=SC1091
  source release/kernel-source.env
fi

TOOLCHAIN="${TOOLCHAIN:-auto}"
if [[ "${TOOLCHAIN}" == "auto" || -z "${TOOLCHAIN}" ]]; then
  if [[ -n "${RECOMMENDED_TOOLCHAIN:-}" ]]; then
    TOOLCHAIN="${RECOMMENDED_TOOLCHAIN}"
  else
    TOOLCHAIN="android-r416183b"
  fi
fi

case "${TOOLCHAIN}" in
  android-r416183b|llvm-22.1.8) ;;
  *)
    echo "::error::Unsupported TOOLCHAIN=${TOOLCHAIN}" >&2
    exit 1
    ;;
esac

echo "TOOLCHAIN=${TOOLCHAIN}"
if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "TOOLCHAIN=${TOOLCHAIN}" >> "${GITHUB_ENV}"
fi
