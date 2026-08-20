#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

PYTHON="${PYTHON:-python3}"

matrix="$(
  BUILD_SOURCE_MELT=true \
  BUILD_SOURCE_LINEAGEOS=true \
  BUILD_KERNELSU_NEXT=true \
  BUILD_SUKISU_ULTRA=true \
  BUILD_RESUKISU=true \
  ENABLE_SUSFS=true \
  GITHUB_OUTPUT=/dev/null \
  PYTHON="${PYTHON}" \
  bash scripts/generate-build-matrix.sh
)"

"${PYTHON}" - "${matrix}" <<'PY'
import json
import sys

data = json.loads(sys.argv[1])
items = data["include"]
assert len(items) == 6
assert [item["kernel_source"] for item in items] == [
    "melt", "melt", "melt",
    "lineageos", "lineageos", "lineageos",
]
assert [item["manager"] for item in items] == [
    "kernelsu-next", "sukisu-ultra", "resukisu",
    "kernelsu-next", "sukisu-ultra", "resukisu",
]
assert all(item["enable_susfs"] == "true" for item in items)
assert [item["label"] for item in items] == [
    "melt-kernelsu-next-susfs", "melt-sukisu-ultra-susfs", "melt-resukisu-susfs",
    "lineageos-kernelsu-next-susfs", "lineageos-sukisu-ultra-susfs", "lineageos-resukisu-susfs",
]
PY

# Test BUILD_SOURCE_ALL
all_matrix="$(
  BUILD_SOURCE_ALL=true \
  BUILD_KERNELSU_NEXT=true \
  ENABLE_SUSFS=true \
  GITHUB_OUTPUT=/dev/null \
  PYTHON="${PYTHON}" \
  bash scripts/generate-build-matrix.sh
)"
"${PYTHON}" - "${all_matrix}" <<'PY'
import json
import sys
data = json.loads(sys.argv[1])
sources = [item["kernel_source"] for item in data["include"]]
assert sources == ["melt", "lineageos", "evolution-x", "aosp-pablo", "pa-gr"]
PY
if BUILD_KERNELSU=true ENABLE_SUSFS=true GITHUB_OUTPUT=/dev/null \
  bash scripts/generate-build-matrix.sh >/dev/null 2>&1; then
  echo "FAIL: KernelSU + SUSFS matrix generation should be rejected" >&2
  exit 1
fi

echo "Matrix generator tests passed"
