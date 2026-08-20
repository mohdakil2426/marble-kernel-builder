#!/usr/bin/env bash
set -euo pipefail

PYTHON="${PYTHON:-python3}"
"${PYTHON}" - config/managers.json config/kernel-sources.json "${GITHUB_OUTPUT:-}" <<'PY'
import json
import os
import sys

managers_path = sys.argv[1]
sources_path = sys.argv[2]
github_output = sys.argv[3] if len(sys.argv) > 3 else ""

with open(managers_path, encoding="utf-8") as fh:
    managers = json.load(fh)
with open(sources_path, encoding="utf-8") as fh:
    kernel_sources = json.load(fh)
build_all_sources = os.environ.get("BUILD_SOURCE_ALL", "false") == "true"

source_flags = [
    ("melt", os.environ.get("BUILD_SOURCE_MELT", "false")),
    ("lineageos", os.environ.get("BUILD_SOURCE_LINEAGEOS", "false")),
    ("evolution-x", os.environ.get("BUILD_SOURCE_EVOLUTION_X", "false")),
    ("aosp-pablo", os.environ.get("BUILD_SOURCE_AOSP_PABLO", "false")),
    ("pa-gr", os.environ.get("BUILD_SOURCE_PA_GR", "false")),
]

ks_env = os.environ.get("KERNEL_SOURCE", "").strip()

if build_all_sources:
    selected_sources = list(kernel_sources.keys())
else:
    selected_sources = [s for s, w in source_flags if w == "true"]
    if not selected_sources and ks_env and ks_env != "auto" and ks_env in kernel_sources:
        selected_sources = [ks_env]
    elif ks_env and ks_env != "auto" and ks_env in kernel_sources and ks_env not in selected_sources:
        selected_sources.append(ks_env)

if not selected_sources:
    print("::error::No kernel sources selected. Enable at least one build_source_* checkbox.", file=sys.stderr)
    sys.exit(1)

manager_flags = [
    ("none", os.environ.get("BUILD_NONE", "false")),
    ("kernelsu", os.environ.get("BUILD_KERNELSU", "false")),
    ("kernelsu-next", os.environ.get("BUILD_KERNELSU_NEXT", "false")),
    ("sukisu-ultra", os.environ.get("BUILD_SUKISU_ULTRA", "false")),
    ("resukisu", os.environ.get("BUILD_RESUKISU", "false")),
]

selected_managers = [m for m, w in manager_flags if w == "true"]
if not selected_managers and os.environ.get("MANAGER"):
    m = os.environ["MANAGER"]
    if m in managers:
        selected_managers = [m]

if not selected_managers:
    print("::error::No managers selected. Enable at least one build_* manager checkbox.", file=sys.stderr)
    sys.exit(1)

enable_susfs = os.environ.get("ENABLE_SUSFS", "false") == "true"
include = []

for source in selected_sources:
    if source not in kernel_sources:
        print(f"::error::Unknown kernel_source preset: {source}", file=sys.stderr)
        sys.exit(1)
    for manager in selected_managers:
        if manager not in managers:
            print(f"::error::Unknown manager preset: {manager}", file=sys.stderr)
            sys.exit(1)
        meta = managers[manager]
        manager_susfs = enable_susfs and bool(meta.get("susfs_ref"))
        if enable_susfs and manager != "none" and not meta.get("susfs_ref"):
            print(f"::error::{manager} does not support SUSFS in config/managers.json", file=sys.stderr)
            sys.exit(1)
        
        mgr_label = f"{manager}-susfs" if manager_susfs else manager
        label = f"{source}-{mgr_label}"
        
        include.append({
            "kernel_source": source,
            "manager": manager,
            "enable_susfs": "true" if manager_susfs else "false",
            "label": label,
        })

matrix = json.dumps({"include": include}, separators=(",", ":"))
if github_output and github_output != "/dev/null":
    with open(github_output, "a", encoding="utf-8") as fh:
        fh.write(f"matrix={matrix}\n")
print(matrix)
PY
