# Verified Defaults

Last updated: **2026-07-13** (branch `feature/pa-gr-kernel-source` — pa-gr SM8450 preset).

| Component | Repo | Default Ref | Version / Commit |
|---|---|---|---|
| Kernel source (`melt`) | `mohdakil2426/android_kernel_xiaomi_marble` | `melt-rebase` | HyperOS / Melt marble source (`marble_defconfig`) |
| Kernel source (`lineageos`) | `LineageOS/android_kernel_xiaomi_sm8450` | `lineage-23.2` | LOS GKI fragments (`gki_defconfig` + marble vendor configs) |
| Kernel source (`evolution-x`) | `Evolution-X-Devices/kernel_xiaomi_sm8450` | `cnb` | LOS-family GKI fragments for Evolution X / custom LOS |
| Kernel source (`aosp-pablo`) | `aosp-pablo/android_kernel_xiaomi_sm8450` | `16` | LOS-family GKI fragments (GitHub org aosp-pablo) |
| Kernel source (`pa-gr`) | `pa-gr/android_kernel_xiaomi_sm8450` | `vauxite` | LOS-family GKI fragments; default branch may ship in-tree KernelSU |
| Android kernel Clang | `https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86` | `master-kernel-build-2021` | commit `6e3223f76384455acde43affde3df0ea9df66c0d`; sparse path `clang-r416183b`, matching `build.config.common` |
| LLVM experimental | `https://github.com/llvm/llvm-project/releases/download/llvmorg-22.1.8/LLVM-22.1.8-Linux-X64.tar.xz` | `llvmorg-22.1.8` | SHA-256 `df0e1ecf16caf3489a272a5eea4eec9b0d82878f6477fa309504f918a0006384`; selectable with `toolchain=llvm-22.1.8` |
| AnyKernel3 | `osm0sis/AnyKernel3` | commit `dca9dc370838d919d56c1f59ec78b27a14a72c68` | Immutable packaging template |
| SUSFS | `https://gitlab.com/simonpunk/susfs4ksu.git` | commit `4003ecf2d01c6d13fa8edf6c4f2607365738dc3d` | `SUSFS_VERSION v2.2.0`; CI-proven with KernelSU-Next/pershoot, official SukiSU Ultra, and ReSukiSU |
| SUSFS older preset | `https://gitlab.com/simonpunk/susfs4ksu.git` | commit `86114db0c49f20fa7857b8b559f3ab87cbc2d00d` | `SUSFS_VERSION v2.1.0`; WildKernels GKI r4 gki-android12-5.10 pin |
| KernelSU | `tiann/KernelSU` | `main` | Official source; non-SUSFS builds only |
| KernelSU-Next | `KernelSU-Next/KernelSU-Next` | `dev` | Official non-SUSFS ref |
| KernelSU-Next + SUSFS | `pershoot/KernelSU-Next` | `dev-susfs` | Fork branch based on official `dev` with SUSFS integration; CI-proven on Marble run `27937351021` |
| Manager version code | (computed in `read-manager-version.sh`) | Wild-style | `git rev-list --count HEAD + BASE` (KSUN/Suki/ReSuki: BASE 10200 if commits&lt;2684 else 30000; KernelSU BASE 30000), inject `DKSU_VERSION`/`KSU_VERSION` into Makefile; fallback to Makefile literal |
| SukiSU Ultra | `SukiSU-Ultra/SukiSU-Ultra` | `main` | Official non-SUSFS ref |
| SukiSU Ultra + SUSFS | `SukiSU-Ultra/SukiSU-Ultra` | `builtin` | Official branch with manager-side SUSFS support |
| ReSukiSU | `ReSukiSU/ReSukiSU` | `main` | Official branch with manager-side SUSFS support |

The workflow resolves branch, tag, and commit inputs to exact commits at run time and records them in `release/build-info.txt`. For SUSFS, the user chooses `susfs_version=v2.2.0`, `susfs_version=v2.1.0`, or `susfs_version=custom`. Custom mode uses `susfs_ref` and verifies `susfs_expected_version` when provided.

Device targets remain Poco F5 (`marblein`) and Redmi Note 12 Turbo (`marble`). ROM support depends on the selected kernel preset: `melt` is stock HyperOS; `lineageos`, `evolution-x`, `aosp-pablo`, and `pa-gr` are for LOS-based custom ROMs only.

**ZIP naming (2026-07-13+):**

```text
AK3_marble_<FAMILY>_<source>_<manager>[-version][-codeN][_susfs-vX.Y.Z]_rN.zip
```

`FAMILY` is `MELT` or `LOS`. Manager version/code stay in the name when available; SUSFS off omits the segment; LTO is not in the filename. Enabling `create_draft_release` creates a ZIP-only draft tag `marble-<preset>-r<run>` without rebuilding.

**Toolchain:** workflow default is `auto` (preset `recommended_toolchain`, else `android-r416183b`).

## Pin refresh

Review `config/known-good-pins.json` and manager SUSFS forks **every 2–4 weeks** or after upstream breaks CI.

## JOBS / ThinLTO overrides (self-hosted)

Free defaults: LLVM `JOBS<=2`, `THINLTO_JOBS=2`. On larger hosts:

```bash
JOBS_FORCE=1 JOBS=8 THINLTO_JOBS=4
```

Manager repositories are allowlisted for normal builds. KernelSU-Next is official `KernelSU-Next/KernelSU-Next@dev` when SUSFS is disabled; when SUSFS is enabled, the workflow intentionally switches only that manager to `pershoot/KernelSU-Next@dev-susfs` because current official KernelSU-Next SUSFS paths are not Marble-compatible. Supported SUSFS paths apply only the kernel-side SUSFS patch/files and verify final Kconfig values. Official KernelSU + SUSFS remains rejected until a compatible integration exists.

The default Android compiler is retrieved with Git partial clone and sparse checkout, not a generated archive. The workflow verifies the remote branch resolves to the pinned commit before checking out `clang-r416183b`. This is intentional because repeated downloads of the official generated Gitiles archive produced different whole-archive SHA-256 values even though the underlying Git commit was unchanged.

LLVM 22.1.8 is **required for LOS-family** kernels (armv9). For **Melt / HyperOS**, keep default `android-r416183b` for release-safe builds; use LLVM on Melt only for experiments.

## Clang LTO and free runners

Workflow input `lto` selects Clang LTO mode for all presets (`none` / `thin` / `full`). Default is **`thin`**.

| Mode | Guidance |
|------|----------|
| `none` | Fastest link; use for debug/smoke builds when LTO is not required |
| `thin` | **Default.** Free-runner safe with the build-core 16 GiB swap, JOBS caps for LLVM 22, and ThinLTO job limits |
| `full` | Highest optimization; memory-heavy — prefer high-RAM hosts; may OOM on free GitHub-hosted runners (~7 GiB) |

Notes:

- **Melt / HyperOS** keeps LTO enabled (default `thin`) with Android `clang-r416183b`.
- **LOS-family** presets (`lineageos`, `evolution-x`, `aosp-pablo`, `pa-gr`) should use `toolchain=llvm-22.1.8` and `lto=thin` on free runners; the workflow enables swap and caps parallelism to reduce OOM risk. `lto=full` is experimental on free runners (OOM risk).
- Ccache: **4 GiB** (Android clang) / **6 GiB** (LLVM 22), content-based compiler checks, multi-level restore-keys (toolchain+LTO → kernel → source → manager).
- ThinLTO: separate Actions cache for `~/.cache/thinlto` when `lto=thin` (similar to WildKernels LTO cache bucket).
- **Object-cache save:** ccache / ThinLTO save on **failure as well as success** (`always() && !cancelled() && exact miss`). Partial compiles (e.g. fail at 90%) still warm the next run. ZIP/release stay success-only.
- **Summary Cache section:** CI/artifact summaries embed Actions hit flags + full `ccache -s` text (same as `ccache-stats.txt`). **Stripped** from GitHub Release notes (`matrix-summary-release.md`).
- Disk: Wild-style SDK cleanup on kernel jobs (especially when LTO is enabled or free space is low).
