#!/usr/bin/env bash
set -euo pipefail

python3 - config/managers.json "${GITHUB_OUTPUT:-}" <<'PY'
import json
import os
import sys

config_path = sys.argv[1]
github_output = sys.argv[2]

with open(config_path, encoding="utf-8") as fh:
    managers = json.load(fh)

selected = [
    ("none", os.environ.get("BUILD_NONE", "false")),
    ("kernelsu", os.environ.get("BUILD_KERNELSU", "false")),
    ("kernelsu-next", os.environ.get("BUILD_KERNELSU_NEXT", "false")),
    ("sukisu-ultra", os.environ.get("BUILD_SUKISU_ULTRA", "false")),
    ("resukisu", os.environ.get("BUILD_RESUKISU", "false")),
]

enable_susfs = os.environ.get("ENABLE_SUSFS", "false") == "true"
include = []

for manager, wanted in selected:
    if wanted != "true":
        continue
    meta = managers[manager]
    manager_susfs = enable_susfs and bool(meta.get("susfs_ref"))
    if enable_susfs and manager != "none" and not meta.get("susfs_ref"):
        print(f"::error::{manager} does not support SUSFS in config/managers.json", file=sys.stderr)
        sys.exit(1)
    label = manager
    if manager_susfs:
        label = f"{manager}-susfs"
    include.append(
        {
            "manager": manager,
            "enable_susfs": "true" if manager_susfs else "false",
            "label": label,
        }
    )

if not include:
    print("::error::No managers selected. Enable at least one build_* checkbox.", file=sys.stderr)
    sys.exit(1)

matrix = json.dumps({"include": include}, separators=(",", ":"))
if github_output and github_output != "/dev/null":
    with open(github_output, "a", encoding="utf-8") as fh:
        fh.write(f"matrix={matrix}\n")
print(matrix)
PY
