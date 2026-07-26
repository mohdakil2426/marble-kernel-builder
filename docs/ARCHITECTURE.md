# Marble Kernel Builder — Architecture

**Audience:** maintainers, contributors, and agents working on CI, packaging, or policy.  
**Scope:** how `marble-kernel-builder` designs and runs builds — not how to flash a phone (see [README](../README.md)).  
**Aligned with:** branch `feature/los-kernel-source-presets` @ tip including naming, toolchain=auto, CI-only Cache section, Wild-style manager version (`338cb9d`+).

---

## Table of contents

1. [Purpose and non-goals](#1-purpose-and-non-goals)
2. [Design principles](#2-design-principles)
3. [System context](#3-system-context)
4. [Repository layout and layering](#4-repository-layout-and-layering)
5. [Workflow topology](#5-workflow-topology)
6. [Matrix generation](#6-matrix-generation)
7. [Kernel source architecture](#7-kernel-source-architecture)
8. [Build-core pipeline (detailed)](#8-build-core-pipeline-detailed)
9. [Manager and SUSFS architecture](#9-manager-and-susfs-architecture)
10. [LTO architecture](#10-lto-architecture)
11. [Caching architecture](#11-caching-architecture)
12. [Packaging and artifacts](#12-packaging-and-artifacts)
13. [Metadata and provenance](#13-metadata-and-provenance)
14. [Testing and quality gates](#14-testing-and-quality-gates)
15. [Security and trust boundaries](#15-security-and-trust-boundaries)
16. [Failure modes (operator map)](#16-failure-modes-operator-map)
17. [Script catalog](#17-script-catalog)
18. [Extensibility guide](#18-extensibility-guide)
19. [Marble vs WildKernels (architecture comparison)](#19-marble-vs-wildkernels-architecture-comparison)
20. [Glossary](#20-glossary)
21. [Related documents](#21-related-documents)
22. [Summary](#22-summary)

---

## 1. Purpose and non-goals

### 1.1 What this system is

Marble Kernel Builder is a **CI-only packaging and integration layer** for:

| Device | Codename |
|--------|----------|
| Poco F5 | `marblein` |
| Redmi Note 12 Turbo | `marble` |

It:

1. Checks out a **clean remote kernel tree** (never permanently patched upstream).
2. Optionally injects an **allowlisted** KernelSU-family manager and **SUSFS** in a temporary workspace.
3. Compiles with a **pinned toolchain** and selectable **Clang LTO** mode.
4. Packages an **AnyKernel3** flashable ZIP plus metadata, audit, and provenance.
5. Optionally creates a **ZIP-only draft GitHub release** from the same successful matrix run.

### 1.2 What this system is not

| Non-goal | Reason |
|----------|--------|
| Full AOSP / Lineage ROM build | Out of scope; kernels only |
| Permanent in-tree KSU/SUSFS forks | Clean two-repo model |
| Arbitrary custom manager URLs | Security / policy allowlist |
| Multi-device mega-matrix (100+ phones) | Single-device focus; simpler scripts |
| Default `full` build_scope shipping modules/dtbs as flash zips | Default is `image-only`; `full` is optional CI target set |

Default CI scope is **`image-only`** (kernel `Image` → AnyKernel ZIP).

---

## 2. Design principles

| Principle | Meaning in practice |
|-----------|---------------------|
| **Two-repo / clean source** | Builder holds workflows + scripts; kernel sources stay remote and unpatched in-tree. |
| **Data over hardcoding** | Managers → `config/managers.json`; kernel presets → `config/kernel-sources.json`; SUSFS pins → `config/susfs-refs.json`; pins/toolchains → `config/marble.env`. |
| **Policy before cost** | Invalid manager/SUSFS/LTO combos fail in validation, not after 20 minutes of compile. |
| **Matrix as single entrypoint** | One user-facing workflow for one or many managers — no parallel “single build” dispatch. |
| **Scripts over mega-YAML** | Logic lives in testable `scripts/*.sh`; workflows orchestrate. Contrasts WildKernels-style heavy `.github/actions` + Python matrices. |
| **Free-runner realism** | Thin LTO + swap + job caps + multi-level caches so GitHub-hosted runners (~7 GiB RAM) can finish LOS/LLVM builds. |
| **Small artifacts** | Flash ZIP + checksum + metadata + summary + audit; no multi-hundred-MB debug bundles. |
| **Provenance first** | Exact commits, toolchain digests, LTO mode, cache hits recorded in `build-info.*`. |

---

## 3. System context

```text
┌──────────────────────────────────────────────────────────────────┐
│  Operator (GitHub Actions UI)                                    │
│  • Managers · kernel_source · lto · toolchain · SUSFS · release  │
└────────────────────────────┬─────────────────────────────────────┘
                             │ workflow_dispatch
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│  marble-kernel-builder (this repo)                               │
│  workflows/  scripts/  config/  ak3/  tests/                     │
└───────────────┬────────────────────────────┬─────────────────────┘
                │ checkout builder           │ resolve + checkout
                │                            ▼
                │              ┌──────────────────────────────────┐
                │              │ Remote kernel source (selected)  │
                │              │ melt | lineageos | evo-x | aosp-pablo | pa-gr │
                │              └──────────────────────────────────┘
                │                            │
                ▼                            ▼
┌──────────────────────────────────────────────────────────────────┐
│  Ephemeral ubuntu-24.04 runner workspace                         │
│  patch manager + SUSFS → compile → AnyKernel ZIP → upload        │
└────────────────────────────┬─────────────────────────────────────┘
                             │
         ┌───────────────────┼───────────────────┐
         ▼                   ▼                   ▼
   Actions artifacts    Actions caches      Optional draft
   (flash + summary)   (clang/llvm/       GitHub Release
                        ccache/thinlto)    (ZIPs only)
```

### Control vs data flow

```text
Control flow (who calls what)
─────────────────────────────
build-matrix.yml
  ├─ setup          → generate-build-matrix.sh + policy tests
  ├─ build[*]       → build-core.yml (workflow_call)
  │                    └─ scripts/* (resolve → validate → patch → build → package)
  ├─ aggregate      → generate-matrix-summary.sh
  └─ release?       → prepare-promoted-release.sh + gh release create

Data flow (what moves)
──────────────────────
config/*.json + marble.env
  → resolve-kernel-source / resolve-refs
  → kernel-source/ + manager + susfs patches (ephemeral)
  → out/Image → release/*.zip + build-info.*
  → artifact marble-flash-… → (optional) draft release assets
```

---

## 4. Repository layout and layering

```text
marble-kernel-builder/
├── .github/
│   ├── workflows/
│   │   ├── build-matrix.yml    # ONLY user-facing build entrypoint
│   │   ├── build-core.yml      # Reusable implementation (workflow_call)
│   │   └── preflight.yml       # Cheap full static gate (no kernel compile)
│   └── dependabot.yml
├── config/
│   ├── marble.env              # Device, pins, toolchain URLs/SHAs
│   ├── managers.json           # Official manager allowlist + refs
│   ├── kernel-sources.json     # Author-named kernel presets
│   └── susfs-refs.json         # SUSFS version → commit map
├── scripts/                    # Primary logic (bash + light Python)
│   ├── resolve-kernel-source.sh
│   ├── validate-inputs.sh
│   ├── generate-build-matrix.sh
│   ├── resolve-refs.sh
│   ├── patch-manager.sh
│   ├── apply-susfs.sh
│   ├── build-kernel.sh
│   ├── package-anykernel.sh
│   ├── prepare-promoted-release.sh
│   ├── generate-build-summary.sh
│   ├── generate-matrix-summary.sh
│   ├── write-build-info-json.sh
│   ├── audit-flashable-zip.sh
│   ├── read-manager-version.sh
│   ├── read-manager-build-metadata.sh
│   └── lib/summary-common.sh
├── ak3/                        # AnyKernel3 overlay only (not full template)
├── tests/                      # Policy + regression shell tests
├── release/                    # Runtime env files (generated; e.g. kernel-source.env)
└── docs/                       # Architecture, versions, matrices
```

### Why not “everything under `.github/`”?

Projects such as **WildKernels** put most automation in composite actions under `.github/actions` and often use Python for large device matrices. Marble deliberately keeps:

| Concern | Location | Benefit |
|---------|----------|---------|
| Orchestration | `.github/workflows/*.yml` | Thin, reviewable |
| Behavior | `scripts/*.sh` | Runnable and unit-tested outside Actions |
| Product data | `config/*.json` / `marble.env` | Single source of truth |
| Regression | `tests/test-*.sh` | Fail fast in preflight / matrix setup |
| Flash overlay | `ak3/` | Small, intentional delta over pinned AnyKernel3 |

### Layer diagram

```text
┌─────────────────────────────────────────────────────────┐
│  Presentation: GitHub Actions UI (workflow_dispatch)    │
└────────────────────────────┬────────────────────────────┘
                             ▼
┌─────────────────────────────────────────────────────────┐
│  Orchestration: build-matrix.yml / preflight.yml        │
└────────────────────────────┬────────────────────────────┘
                             ▼
┌─────────────────────────────────────────────────────────┐
│  Implementation: build-core.yml (workflow_call)         │
└────────────────────────────┬────────────────────────────┘
                             ▼
┌─────────────────────────────────────────────────────────┐
│  Domain logic: scripts/*.sh                             │
└────────────────────────────┬────────────────────────────┘
                             ▼
┌─────────────────────────────────────────────────────────┐
│  Product data: config/*  ·  Flash skin: ak3/            │
└─────────────────────────────────────────────────────────┘
```

---

## 5. Workflow topology

### 5.1 Entry points

| Workflow | File | Trigger | Cost |
|----------|------|---------|------|
| **Build Marble Kernel** | `build-matrix.yml` | Manual `workflow_dispatch` | High (compiles) |
| **Marble Builder Preflight** | `preflight.yml` | `push` main, PR, manual | Low (static only) |
| **Reusable Marble Kernel Build** | `build-core.yml` | `workflow_call` only | High (implementation) |

There is **no** separate single-build dispatch. One manager or many managers both go through the matrix workflow.

### 5.2 Job graph (`build-matrix.yml`)

```text
                    ┌─────────────┐
                    │   setup     │
                    │ policy +    │
                    │ matrix JSON │
                    └──────┬──────┘
                           │
           ┌───────────────┼───────────────┐
           ▼               ▼               ▼
     ┌──────────┐   ┌──────────┐   ┌──────────┐
     │ build    │   │ build    │   │ build    │  …  (matrix.include[])
     │ core #1  │   │ core #2  │   │ core #N  │
     └────┬─────┘   └────┬─────┘   └────┬─────┘
          │              │              │
          └──────────────┼──────────────┘
                         ▼
              ┌────────────────────┐
              │ aggregate-summary  │  (if: always())
              │ download flash-*   │
              │ combined summary   │
              └─────────┬──────────┘
                        │
                        ▼
              ┌────────────────────┐
              │ release (optional) │
              │ only if draft=true │
              │ AND both success   │
              └────────────────────┘
```

| Job | Runner | Role |
|-----|--------|------|
| `setup` | `ubuntu-24.04` | Fast policy subset + `generate-build-matrix.sh` → outputs `matrix` |
| `build` | Reusable `build-core` | One job per matrix entry; `fail-fast: false` |
| `aggregate-summary` | `ubuntu-24.04` | Downloads `marble-flash-*-r{run}`; writes combined summary; uploads summary artifact |
| `release` | `ubuntu-24.04` | Conditional draft release; `contents: write` only here |

**Concurrency group** (no cancel-in-progress):

```text
workflow + ref + kernel_source + lto + enable_susfs + build_scope
```

Parallel matrix builds of different managers share the group key only when those inputs match; same config re-runs wait rather than cancel each other.

### 5.3 User-facing inputs (`build-matrix.yml`)

| Input | Type | Default | Notes |
|-------|------|---------|-------|
| `build_none` … `build_resukisu` | boolean | false | At least one required |
| `enable_susfs` | boolean | false | Applies to KSUNext / SukiSU / ReSukiSU only |
| `susfs_version` | choice | `v2.2.0` | `v2.2.0` · `v2.1.0` · `custom` |
| `susfs_ref` | string | empty | Only for custom SUSFS |
| `kernel_source` | choice | `melt` | `melt` · `lineageos` · `evolution-x` · `aosp-pablo` · `pa-gr` |
| `source_ref` | string | empty | Override preset branch/tag/commit |
| `build_scope` | choice | `image-only` | `image-only` · `full` |
| `toolchain` | choice | `android-r416183b` | Or `llvm-22.1.8` (required for LOS armv9) |
| `lto` | choice | `thin` | `none` · `thin` · `full` |
| `enable_ccache` | boolean | true | Object cache layer |
| `create_draft_release` | boolean | false | ZIP-only draft on full success |

Hardcoded on matrix → core for SUSFS kernel branch:

```text
susfs_kernel_branch: gki-android12-5.10
```

### 5.4 Permissions

| Job | Permissions |
|-----|-------------|
| Default / setup / aggregate | `contents: read` (+ `actions: read` where artifacts are downloaded) |
| Build (`build-core`) | `contents: read`, `id-token: write`, `attestations: write` |
| Release | `actions: read`, `contents: write` |

Build jobs never get write access to the repo. Only the optional release job can create tags/releases.

### 5.5 Preflight (`preflight.yml`)

Runs on push to `main`, pull requests, and manual dispatch:

1. `bash -n` syntax on scripts/tests  
2. `shellcheck` (with documented exclusions)  
3. `actionlint`  
4. Full `tests/test-*.sh` suite  
5. `git diff --check` whitespace  

No kernel compile — intentionally cheap.

---

## 6. Matrix generation

**UI:** static checkboxes in `build-matrix.yml` (GitHub requires a fixed input schema).  
**Logic:** `scripts/generate-build-matrix.sh` + `config/managers.json`.

### Inputs consumed

```text
BUILD_NONE, BUILD_KERNELSU, BUILD_KERNELSU_NEXT,
BUILD_SUKISU_ULTRA, BUILD_RESUKISU, ENABLE_SUSFS
```

### Behavior

1. Include only managers with checkbox `true`.
2. If SUSFS is on and manager has no `susfs_ref` in `managers.json` → **error** before fan-out.
3. Label becomes `manager` or `manager-susfs` when SUSFS applies.
4. Empty selection → **error**.

### Row → `build-core` mapping

| Shared across matrix | Per row |
|----------------------|---------|
| `kernel_source`, `source_ref` | `manager` |
| `toolchain`, `lto`, `build_scope` | `enable_susfs` |
| SUSFS version / kernel branch / custom ref | `artifact_label` |
| `enable_ccache` | |

Child builds set:

- `run_policy_tests: false` — suite already ran in setup/preflight  
- `publish_step_summary: false` — only aggregate publishes the human-facing combined summary  

Strategy: `fail-fast: false` so one manager failure does not cancel siblings.

---

## 7. Kernel source architecture

### 7.1 Presets (`config/kernel-sources.json`)

| ID | Display | Repo | Default ref | Defconfig mode | ROM family |
|----|---------|------|-------------|----------------|------------|
| `melt` | Melt | `mohdakil2426/android_kernel_xiaomi_marble` | `melt-rebase` | `single` → `marble_defconfig` | HyperOS |
| `lineageos` | LineageOS | `LineageOS/android_kernel_xiaomi_sm8450` | `lineage-23.2` | `gki_fragments` | LOS |
| `evolution-x` | Evolution-X | `Evolution-X-Devices/kernel_xiaomi_sm8450` | `cnb` | `gki_fragments` | LOS |
| `aosp-pablo` | aosp-pablo | `aosp-pablo/android_kernel_xiaomi_sm8450` | `16` | `gki_fragments` | LOS |
| `pa-gr` | pa-gr | `pa-gr/android_kernel_xiaomi_sm8450` | `vauxite` | `gki_fragments` | LOS |

LOS presets recommend **`llvm-22.1.8`** (armv9 march flags rejected by Android clang-12 / `clang-r416183b`).

**pa-gr note:** default `vauxite` includes an in-tree `KernelSU` submodule / `drivers/kernelsu`. Out-of-tree manager apply may conflict — treat first CI runs as smoke tests.

### 7.1.1 Source-local patches (optional, removable)

Some presets may declare `source_patches` in `kernel-sources.json`:

```json
"source_patches": {
  "enabled": true,
  "dir": "patches/kernel-sources/pa-gr/vauxite",
  "match_refs": ["vauxite"]
}
```

| Rule | Behavior |
|------|----------|
| Scope | **Only** that preset + refs in `match_refs` |
| When | After kernel checkout, **before** manager / SUSFS (`scripts/apply-kernel-source-patches.sh`) |
| Storage | Builder repo under `patches/kernel-sources/<preset>/…` — **not** pushed to the kernel upstream |
| Failure | `patch` reject → hard fail (forces remove/update when upstream already fixed) |
| Other presets | No-op |

**Current:** `pa-gr` @ `vauxite` — Clang 22 KVM `clidr` init. See `patches/kernel-sources/pa-gr/README.md` for removal steps.

### 7.2 Defconfig modes

**`single` (Melt):**

```text
make O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 CC=… marble_defconfig
```

**`gki_fragments` (LOS family)** — same chain as Lineage device trees:

```text
gki_defconfig
  + arch/arm64/configs/vendor/waipio_GKI.config
  + arch/arm64/configs/vendor/xiaomi_GKI.config
  + arch/arm64/configs/vendor/marble_GKI.config
  + arch/arm64/configs/vendor/debugfs.config
```

Merged via `scripts/kconfig/merge_config.sh -O out -m out/.config <fragments…>`, then LTO/KSU flags and `olddefconfig`.

### 7.3 Resolution (`scripts/resolve-kernel-source.sh`)

Produces env exports and `release/kernel-source.env` including:

| Variable | Purpose |
|----------|---------|
| `SOURCE_REPO`, `SOURCE_REF` | Checkout target |
| `KERNEL_SOURCE`, display/author | Identity |
| `SUPPORTED_ROM_LABEL`, `ROM_FAMILY`, `ROM_SUPPORT` | Packaging + messaging |
| `DEFCONFIG_MODE` | `single` or `gki_fragments` |
| `DEFCONFIG` / `BASE_DEFCONFIG` / `CONFIG_FRAGMENTS` | Config construction |

Optional workflow `source_ref` overrides the preset default branch/tag/commit.

### 7.4 ROM compatibility (product truth)

| Preset family | Supported ROM messaging |
|---------------|-------------------------|
| Melt | Stock HyperOS-oriented |
| LOS three | LineageOS-based custom ROMs only |

ZIP names (locked multi-kernel format):

```text
AK3_marble_<FAMILY>_<source>_<manager>[-version][-codeN][_susfs-vX.Y.Z]_rN.zip
```

`FAMILY` is `MELT` or `LOS`. Draft tags: `marble-<kernel_source>-r<run>`.

---

## 8. Build-core pipeline (detailed)

Each matrix entry runs **one** `build-core` job (`timeout-minutes: 120`, `ubuntu-24.04`).

### Stage A — Bootstrap

| Step | Action |
|------|--------|
| Checkout builder | At workflow SHA; credentials not persisted |
| Policy tests | Only if `run_policy_tests=true` (matrix sets false) |
| Resolve preset | `resolve-kernel-source.sh` |
| Validate | `validate-inputs.sh` (managers, SUSFS, LTO, source shape) |
| Checkout kernel | Into `kernel-source/` (`fetch-depth: 1`) |
| Disk cleanup | Aggressive when LTO ≠ none or free space &lt; 40 GiB (dotnet/android/ghc/boost/swift) |
| Swap | **16 GiB** if `lto != none` (`pierotofy/set-swap-space`) |
| apt deps | `ccache`, `clang`, `lld`, `bc`, `bison`, `flex`, `jq`, … |

### Stage B — Toolchain

| `toolchain` input | Fetch strategy | Integrity |
|-------------------|----------------|-----------|
| `android-r416183b` | Partial clone + sparse checkout of `clang-r416183b` from AOSP prebuilts | Commit must equal `6e3223f…` in `marble.env` |
| `llvm-22.1.8` | Official GitHub release tarball | SHA-256 `df0e1ecf…` |

Both restore from Actions cache when available, then **Select active toolchain** exports:

```text
ANDROID_CLANG_BIN, ACTIVE_TOOLCHAIN_ID,
ACTIVE_TOOLCHAIN_VERSION, ACTIVE_TOOLCHAIN_COMMIT, ACTIVE_TOOLCHAIN_DIGEST
```

into `GITHUB_ENV` for later steps and `build-info`.

### Stage C — Identity and caches

1. **`resolve-refs.sh`** — exact manager + SUSFS commits, tags, URLs → `release/resolved-refs.env`.  
2. **Generate cache keys** (when ccache enabled and/or `lto=thin`) — see [§11](#11-caching-architecture).  
3. Restore ccache directory if enabled.  
4. Restore ThinLTO cache if `lto=thin`.

### Stage D — Integrate (workspace only)

| Script | Role |
|--------|------|
| `patch-manager.sh` | Download manager `kernel/setup.sh` at pinned commit; run against `kernel-source/` (no-op for `none`) |
| `read-manager-version.sh` | Optional numeric version from manager Makefile |
| `apply-susfs.sh` | Clone simonpunk SUSFS pin; apply GKI patch + rsync fs/include; require manager Kconfig `KSU_SUSFS` |

Patches never land on the remote kernel or manager repos — only on the ephemeral runner tree.

### Stage E — Compile and package

**`build-kernel.sh`:**

1. Defconfig mode `single` or `gki_fragments`.  
2. Force `CONFIG_KSU` / `CONFIG_KSU_SUSFS` when required.  
3. Apply **LTO** (`none` / `thin` / `full`) via `scripts/config`.  
4. `olddefconfig`; assert final `.config` has required symbols.  
5. LLVM free-runner: cap `JOBS` to **2** unless `JOBS_FORCE` set.  
6. Thin LTO: `ld.lld` wrapper with `--thinlto-jobs=2` and `--thinlto-cache-dir`.  
7. `make Image` (and `modules` + `dtbs` if `build_scope=full`).  
8. Sanity: `Image` exists and size ≥ 5 000 000 bytes; copy to `release/`.

Then:

| Script | Role |
|--------|------|
| `read-manager-build-metadata.sh` | Parse compile log for manager version fields |
| `package-anykernel.sh` | Pin AnyKernel3, overlay `ak3/`, embed `Image`, name ZIP |
| write `build-info.txt` / JSON | Provenance |
| `audit-flashable-zip.sh` | Structural checks |
| `generate-build-summary.sh` | Per-build summary (step summary only if allowed) |

### Stage F — Publish

1. `actions/attest` on `kernel-source/release/*.zip`.  
2. Upload artifact `marble-flash-<label>-<scope>-r<run>` (zip, sha256, metadata, summary, audit, ccache stats).  
3. Save ccache / ThinLTO on **miss** even if the job **failed** (`!cancelled()`); skip on cancel or exact hit.

### Timeline

```text
Timeline (single build-core job)
─────────────────────────────────────────────────────────────
0%   checkout + resolve + validate
10%  kernel checkout + disk/swap + deps
25%  toolchain restore/fetch
35%  refs + cache restore
45%  manager + SUSFS
50–90% compile (dominant wall time)
92%  package + audit
95%  attest + upload
98%  cache save
100% done
```

---

## 9. Manager and SUSFS architecture

### 9.1 Allowlist (`config/managers.json`)

Enforced by **`validate-inputs.sh`** and tests. No arbitrary custom manager repositories.

| Manager | Non-SUSFS | SUSFS |
|---------|-----------|--------|
| `none` | Baseline no-root | **Blocked** |
| `kernelsu` | `tiann/KernelSU@main` | **Blocked** (no official path) |
| `kernelsu-next` | `KernelSU-Next/…@dev` | **`pershoot/KernelSU-Next@dev-susfs` only** |
| `sukisu-ultra` | `@main` | `@builtin` |
| `resukisu` | `@main` | `@main` (built-in support) |

### 9.2 Manager apply path

```text
resolve-refs.sh
  → manager_repo, manager_commit, manager_setup_path
patch-manager.sh
  → curl raw.githubusercontent.com/{repo}/{commit}/{setup_path}
  → bash setup.sh {commit}   # inside kernel-source/
```

### 9.3 SUSFS

| Concern | Detail |
|---------|--------|
| Kernel branch | Always `gki-android12-5.10` in matrix → core |
| Pins | `config/susfs-refs.json`: `v2.2.0` → `4003ecf2…`, `v2.1.0` → `86114db0…` |
| Upstream | `https://gitlab.com/simonpunk/susfs4ksu.git` |
| Kernel apply | Patch `50_add_susfs_in_gki-android12-5.10.patch` + rsync `fs/` + `include/` |
| Manager side | Require `config KSU_SUSFS` in manager Kconfig; **no** fragile generic double-patch for official paths |
| Final config | Must have `CONFIG_KSU_SUSFS=y` when enabled |

`custom` SUSFS version uses operator-supplied `susfs_ref` (and optional expected version checks).

---

## 10. LTO architecture

| Mode | Config intent | Free-runner notes |
|------|---------------|-------------------|
| `none` | LTO disabled (`LTO_NONE` / clear clang LTO) | Fastest link; no LTO swap required |
| `thin` | **Default** — `LTO_CLANG` + `LTO_CLANG_THIN` | Swap 16 GiB; thinlto-jobs=2; ThinLTO Actions cache |
| `full` | `LTO_CLANG` + `LTO_CLANG_FULL` | Optional; memory-heavy; warning emitted |

### Application order (inside `build-kernel.sh`)

```text
defconfig / merge fragments
  → enable KSU / KSU_SUSFS if needed
  → scripts/config LTO flags for selected mode
  → olddefconfig
  → assert CONFIG_KSU / CONFIG_KSU_SUSFS
  → optional ThinLTO ld.lld wrapper
  → make -j$JOBS Image …
```

### Free-runner hardening

| Control | When | Value |
|---------|------|-------|
| Swap | `lto != none` | 16 GiB |
| `JOBS` | `toolchain=llvm-22.1.8` | Cap **2** |
| ThinLTO jobs | `lto=thin` | **2** |
| ThinLTO cache dir | `lto=thin` | `~/.cache/thinlto` |

**Melt:** LTO follows the workflow input (default thin); never permanently forced off.  
**LOS:** Prefer `thin` + `llvm-22.1.8` on free GitHub-hosted runners.

Historical note: permanent “force LTO off” for Melt was intentionally **removed**. Selectable LTO + swap + caps is the supported model.

---

## 11. Caching architecture

```text
┌────────────────────┐     ┌────────────────────┐
│ Toolchain cache    │     │ Object ccache      │
│ clang-r416183b or  │     │ ~/.ccache          │
│ LLVM 22.1.8 tree   │     │ 4G / 6G, content   │
└────────────────────┘     │ check, v4 keys     │
                           └────────────────────┘
┌────────────────────┐
│ ThinLTO cache      │  only when lto=thin
│ ~/.cache/thinlto   │  separate Actions key
└────────────────────┘
```

### 11.1 Toolchain caches

| Toolchain | Cache path | Key sketch |
|-----------|------------|------------|
| Android clang | `android-clang` | `marble-builder-clang-v3-…-clang-r416183b-6e3223f` |
| LLVM 22.1.8 | `llvm-22.1.8` | `marble-builder-llvm-v1-…-22.1.8-df0e1ecf` |

### 11.2 Ccache (object)

| Setting | Value |
|---------|--------|
| Size | **4 GiB** (Android clang) · **6 GiB** (LLVM 22) |
| Compiler check | `CCACHE_COMPILERCHECK=content` |
| Compression | on (level 6 when supported) |
| Key prefix | `marble-builder-ccache-v4-…` |

**Exact key hierarchy** (most specific first for restore-keys fallback):

```text
key =
  marble-builder-ccache-v4-{os}-{arch}-{toolchain}-lto{mode}
    -{kernel_source}
    -{source_commit}
    -{manager}
    -{manager_commit}-{susfs_commit}-{build_scope}-{config_hash}

restore-keys (prefix match, broadest last):
  manager_prefix-
  source_prefix-
  kernel_prefix-
  base-
```

`config_hash` hashes: `build-kernel.sh`, `marble.env`, `managers.json`, `susfs-refs.json`, `kernel-sources.json`, `resolve-kernel-source.sh`.

### 11.3 ThinLTO cache

```text
thinlto_key =
  marble-builder-thinlto-v1-{os}-{arch}-{toolchain}-{kernel_id}-{source_commit}-lto{mode}

thinlto_prefix (restore-keys) =
  marble-builder-thinlto-v1-{os}-{arch}-{toolchain}-{kernel_id}-lto{mode}
```

Path restored/saved: `/home/runner/.cache/thinlto`.

### 11.4 Save policy

GitHub Actions **exact keys are immutable**. Marble saves **object caches** (ccache / ThinLTO) when:

```text
always() && !cancelled() && cache-hit != 'true'
```

So a build that fails at ~90% compile still persists partial objects for the next run. Manual cancel does not save. Exact key already hit → skip save (immutable).

**Product artifacts** (ZIP upload, attestation, draft release) remain **success-only**.

Bump the **version prefix** (`v4`, `v1`, …) when key semantics change so stale buckets do not poison builds.

### 11.5 Comparison note

WildKernels often uses composite actions + separate LTO cache buckets and multi-device matrices. Marble’s stack is intentionally smaller but includes the same *ideas*: multi-prefix restore, ThinLTO cache, swap, and disk free.

---

## 12. Packaging and artifacts

### 12.1 AnyKernel3

1. Clone pinned AnyKernel3 commit (`ANYKERNEL3_REF` in `marble.env`: `dca9dc37…`).  
2. Overlay project files from `ak3/` only (`rsync -a` — **no** `--delete` of upstream template).  
3. Generate **text-only** dynamic `banner` (Family/Source/Manager/SUSFS/LTO/Run — no ASCII art).  
4. Place `Image` at zip root.  
5. Zip with high compression; write `.sha256`.

### 12.2 ZIP naming

```text
AK3_marble_<FAMILY>_<source>_<manager>[-version][-codeN][_susfs-vX.Y.Z]_rN.zip
```

| Token | Values |
|-------|--------|
| `FAMILY` | `MELT` (`melt`) · `LOS` (lineageos / evolution-x / aosp-pablo / pa-gr) |
| `manager` | `noroot` · `kernelsu` · `ksunext` · `sukisu` · `resukisu` |
| SUSFS off | omit segment |
| LTO | **not** in zip name (banner + build-info) |

Examples:

```text
AK3_marble_MELT_melt_ksunext-v3.2.0-code33203_susfs-v2.2.0_r121.zip
AK3_marble_LOS_lineageos_ksunext-v3.2.0-code33203_susfs-v2.2.0_r121.zip
AK3_marble_MELT_melt_noroot_r124.zip
```

### 12.3 Artifact contents

```text
marble-flash-<label>-<scope>-r<run>/
├── *.zip
├── *.zip.sha256
├── build-info.txt
├── build-info.json
├── summary.md
├── zip-audit.txt
├── ccache-stats.txt
└── zip-name.env
```

| Property | Value |
|----------|--------|
| Retention | 30 days |
| Compression | level 0 (ZIPs already compressed) |
| Missing files | `if-no-files-found: error` |

### 12.4 Draft release

When `create_draft_release=true` **and** build + aggregate both succeed:

1. Download all flash artifacts for the run.  
2. `prepare-promoted-release.sh` verifies structure + checksums; writes `release-assets.txt`.  
3. Regenerates matrix summary, then **strips the CI-only Cache section** → `matrix-summary-release.md`.  
4. `gh release create` **draft** with **only clean ZIPs** (checksums not attached as release assets).  
5. Tag: `marble-<kernel_source>-r<run_number>`.  
6. Title: `Marble Kernel · <Display> · rN`.  
7. Notes: **`matrix-summary-release.md`** (no Cache / ccache-stats block).  
8. Target: workflow SHA; fail if tag/release already exists.

No GitHub Environment deployment approval gate.

### 12.5 Summaries

| Document | Where | Cache section? |
|----------|--------|----------------|
| Per-build `summary.md` | Flash artifact | **Yes** — Actions hits + full `ccache -s` text |
| `matrix-summary.md` | CI artifact / step summary | **Yes** — per-manager hits + `ccache -s` |
| `matrix-summary-release.md` | Draft release notes only | **No** (stripped) |

Kernel Source row links the preset id in parentheses to `https://github.com/<source_repo>`. Credits use dynamic author/repo (never hardcoded maintainers).

---

## 13. Metadata and provenance

| File | Role |
|------|------|
| `release/resolved-refs.env` | Source-safe shell vars (manager/SUSFS commits, tags, version code) |
| `release/kernel-source.env` | Resolved preset outputs + `PACKAGE_FAMILY` |
| `build-info.txt` | Human-readable key=value for artifacts |
| `build-info.json` | Structured metadata for tooling |
| `summary.md` | Human CI/artifact summary (includes CI Cache section) |
| `zip-audit.txt` | Structural audit of flash ZIP |
| `ccache-stats.txt` | Raw `ccache -s` (also embedded in summary Cache section) |

### Notable `build-info` fields

```text
kernel_source, kernel_source_display, rom_family, rom_support, package_family,
source_repo, source_ref, source_commit,
manager_*, manager_version_code, manager_version_method, susfs_*,
toolchain, toolchain_digest, lto, quality_label,
ccache_key, ccache_hit, thinlto_cache_key, thinlto_cache_hit,
workflow_run, runner_image_os / version, disk_available_before_build_gib
```

**Manager version (Wild-style):** after apply, `read-manager-version.sh` computes  
`code = git rev-list --count + BASE` (KSUN family BASE 10200/30000; KernelSU 30000), injects `DKSU_VERSION`/`KSU_VERSION` when present, seeds `manager_build_version_code`. Fallback: Makefile literal.

Shared summary helpers live in `scripts/lib/summary-common.sh`.

---

## 14. Testing and quality gates

| Gate | What runs |
|------|-----------|
| **preflight.yml** | Full `tests/test-*.sh`, shellcheck, actionlint, `bash -n`, whitespace |
| **matrix setup** | Fast subset: workflow-policy, lto-policy, manager-policy, matrix-generator, susfs-presets |
| **build-core** | Runtime `validate-inputs` + zip audit; full tests only if `run_policy_tests=true` |

### Test inventory (representative)

| Test | Guards |
|------|--------|
| `test-kernel-sources.sh` | Preset resolution, defconfig modes |
| `test-lto-policy.sh` | LTO validation / workflow defaults |
| `test-workflow-policy.sh` | Pins, swap, caches, matrix wiring |
| `test-manager-policy.sh` | Allowlist + SUSFS matrix rules |
| `test-matrix-generator.sh` | Checkbox → JSON include rows |
| `test-susfs-presets.sh` | Version pins |
| `test-package-naming.sh` | ZIP name rules |
| `test-promote-release.sh` | Draft release prep invariants |
| `test-build-info-json.sh` / summary tests | Metadata shape |

Policy tests run with related env vars **unset** so ambient CI env cannot fake pass.

---

## 15. Security and trust boundaries

| Boundary | Policy |
|----------|--------|
| Manager source | Official allowlist only (+ documented `pershoot` SUSFS exception for KSUNext) |
| Kernel source | Operator-selected preset or override ref; still remote GitHub |
| Secrets | Default `GITHUB_TOKEN`; no broad write on build jobs |
| Supply chain | Actions pinned by commit SHA; Dependabot for actions; ZIP attestation (`actions/attest`) |
| Toolchains | Commit pin (Android clang) or SHA-256 (LLVM tarball) |
| Patches | Exist only on ephemeral runners |
| Release write | Isolated to optional release job |

---

## 16. Failure modes (operator map)

| Symptom | Likely stage | Hint |
|---------|--------------|------|
| Matrix setup fails tests | setup | Policy regression or broken workflow pin |
| “No managers selected” | setup | Enable at least one `build_*` checkbox |
| SUSFS + kernelsu / none rejected | validate | Use ksunext / sukisu / resukisu |
| armv9 / clang-12 errors | compile LOS | Use `toolchain=llvm-22.1.8` |
| Exit 137 / OOM | link LTO | Prefer `lto=thin`, ensure swap path, avoid `full` on free runners |
| Exit 143 runner shutdown | free tier load | Avoid many heavy parallel LOS jobs |
| Missing config fragment | defconfig | Wrong tree/ref for LOS fragments |
| `CONFIG_KSU` / `CONFIG_KSU_SUSFS` not y | after olddefconfig | Manager/SUSFS integration failed |
| Aggregate fails “no artifacts” | post-build | All build jobs failed before upload |
| Release skipped | end | Checkbox off or build/summary not both success |
| “Release/tag already exists” | release | Bump run or delete conflicting draft tag carefully |

---

## 17. Script catalog

| Script | Phase | Responsibility |
|--------|-------|----------------|
| `resolve-kernel-source.sh` | Bootstrap | Map `KERNEL_SOURCE` → repo/ref/defconfig/ROM labels |
| `validate-inputs.sh` | Bootstrap | Reject illegal manager/SUSFS/LTO/source combos |
| `generate-build-matrix.sh` | Matrix setup | Checkboxes → JSON strategy matrix |
| `resolve-refs.sh` | Identity | Pin manager + SUSFS to exact commits |
| `apply-kernel-source-patches.sh` | Integrate | Optional preset/ref-gated source overlays (e.g. pa-gr) |
| `patch-manager.sh` | Integrate | Run allowlisted manager `setup.sh` |
| `apply-susfs.sh` | Integrate | Kernel SUSFS patch + manager Kconfig gate |
| `build-kernel.sh` | Compile | Defconfig, LTO, make, Image validation |
| `read-manager-version.sh` | Metadata | Makefile version (optional) |
| `read-manager-build-metadata.sh` | Metadata | Log-derived manager version fields |
| `package-anykernel.sh` | Package | Pin AK3, overlay, ZIP + sha256 |
| `write-build-info-json.sh` | Metadata | Structured build-info |
| `audit-flashable-zip.sh` | Package | Structural ZIP audit |
| `generate-build-summary.sh` | Summary | Per-job summary.md |
| `generate-matrix-summary.sh` | Aggregate | Combined multi-manager summary |
| `prepare-promoted-release.sh` | Release | Verify artifacts; list ZIP-only assets |
| `lib/summary-common.sh` | Shared | Formatting helpers for summaries |

---

## 18. Extensibility guide

### Add a kernel preset

1. Add entry to `config/kernel-sources.json` (repo, ref, defconfig mode, ROM label, notes).  
2. Add option to `build-matrix.yml` `kernel_source` choice.  
3. Extend `tests/test-kernel-sources.sh` + workflow policy options list.  
4. Document ROM family and recommended toolchain in README / versions.md.  
5. Smoke CI with `image-only` + appropriate toolchain/LTO.

### Add a manager (rare; policy-heavy)

1. Official repo + stable `kernel/setup.sh` path.  
2. Update `managers.json`, validate-inputs, matrix generator checkboxes, tests, README matrix.  
3. Decide SUSFS story (`susfs_ref` empty = blocked).  
4. Prove CI (and ideally device boot) before calling it stable.

### Change LTO or cache behavior

1. Prefer `build-kernel.sh` + `build-core.yml` + policy tests.  
2. Bump ccache/thinlto key **version prefix** when semantics change.  
3. Re-verify free-runner path: swap, JOBS cap, thinlto-jobs.

### Change packaging

1. Prefer overlay in `ak3/` over forking AnyKernel3.  
2. Bump `ANYKERNEL3_REF` only with explicit pin + versions.md update.  
3. Keep naming tests green (`test-package-naming.sh`).

---

## 19. Marble vs WildKernels (architecture comparison)

| Dimension | Marble | WildKernels-style (typical) |
|-----------|--------|-----------------------------|
| Device scope | Poco F5 / marble only | Multi-device matrices |
| Logic home | `scripts/*.sh` + `config/*` | Heavy `.github/actions` composites |
| Matrix language | Bash generator + static checkboxes | Often Python / large JSON configs |
| Kernel sources | Named presets (Melt + LOS family) | Per-device manifests |
| Caching | Toolchain + ccache v4 + ThinLTO | Mega multi-bucket caches |
| Complexity | Smaller, auditable | Higher scale, higher complexity |
| Free runners | First-class (swap, JOBS=2, thin) | Often assume larger runners |
| Extensibility | Add JSON + tests + dropdown | Add device config + action wiring |

Marble intentionally optimizes for **correctness, allowlists, and free-runner builds** rather than mega-scale multi-device fan-out.

---

## 20. Glossary

| Term | Meaning |
|------|---------|
| **Builder** | This repo — workflows, scripts, config; not a permanent kernel fork |
| **Preset** | Named kernel source entry in `kernel-sources.json` |
| **GKI fragments** | Base `gki_defconfig` + vendor config fragments merged for LOS trees |
| **Manager** | KernelSU-family root integration applied via `setup.sh` |
| **SUSFS** | Hide/spoof framework (simonpunk) integrated with compatible managers |
| **ThinLTO** | Incremental link-time optimization; default free-runner-safe LTO mode |
| **Matrix** | Parallel manager builds driven by `build-matrix.yml` |
| **Artifact** | GitHub Actions upload of flash ZIP + metadata for one matrix row |
| **Draft release** | Optional ZIP-only GitHub release created from a successful run |
| **Image-only** | Default build scope: kernel `Image` only (no modules/dtbs packaging requirement) |

---

## 21. Related documents

| Doc | Contents |
|-----|----------|
| [README.md](../README.md) | User-facing usage, inputs, flash warnings |
| [versions.md](versions.md) | Pins, LTO/free-runner guidance |
| [manager-matrix.md](manager-matrix.md) | Manager × SUSFS matrix |
| Workspace `memory-bank/` | Agent-oriented current state (outside this git root when using monorepo workspace) |
| Workspace `docs/superpowers/plans/` | Historical implementation plans (LTO, matrix, releases) |

---

## 22. Summary

Marble’s architecture is a **thin orchestration layer** over:

- **data-driven** kernel and manager selection,  
- a **reusable, staged build-core pipeline**,  
- **ephemeral** manager/SUSFS integration,  
- **free-runner-aware** LTO and multi-level caching,  
- and **matrix aggregation** with optional ZIP-only draft releases.

That split—**clean sources**, **testable scripts**, **allowlisted integrations**, and **honest ROM-family boundaries**—is the invariant to preserve when extending the system.

```text
Operator inputs
      │
      ▼
setup (policy + matrix)
      │
      ▼
build-core × N  ──►  flash artifacts + provenance
      │
      ▼
aggregate summary  ──►  optional draft release (ZIPs only)
```
