#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

PYTHON="${PYTHON:-python3}"
"${PYTHON}" - <<'PY'
import json
import re

with open("config/susfs-refs.json", encoding="utf-8") as handle:
    families = json.load(handle)

for family, versions in families.items():
    for version, preset in versions.items():
        ref = preset["ref"]
        commit = preset["commit"]
        if not re.fullmatch(r"[0-9a-f]{40}", ref):
            raise SystemExit(f"FAIL: {family} {version} ref is not a pinned commit: {ref}")
        if ref != commit:
            raise SystemExit(f"FAIL: {family} {version} ref and commit differ")

print("SUSFS preset tests passed")
PY
