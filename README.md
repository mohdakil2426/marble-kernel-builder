<div align="center">

<img src="docs/assets/marble-banner.svg" alt="Marble Kernel Builder" width="720" />

<br/>

**CI-driven AnyKernel3 kernel builder for Poco F5 / Redmi Note 12 Turbo**

`marble` · `marblein`

<br/>

[![Build](https://img.shields.io/badge/GitHub_Actions-CI_Builder-2088FF?logo=githubactions&logoColor=white)](https://github.com/mohdakil2426/marble-kernel-builder/actions)
[![Device](https://img.shields.io/badge/Device-Poco_F5_%2F_RN12_Turbo-EF5350)](https://github.com/mohdakil2426/android_kernel_xiaomi_marble)
[![KernelSU](https://img.shields.io/badge/KernelSU-Supported-4CAF50?logo=linux&logoColor=white)](https://github.com/tiann/KernelSU)
[![KernelSU-Next](https://img.shields.io/badge/KernelSU--Next-Supported-4CAF50?logo=linux&logoColor=white)](https://github.com/KernelSU-Next/KernelSU-Next)
[![SukiSU Ultra](https://img.shields.io/badge/SukiSU_Ultra-Supported-4CAF50?logo=linux&logoColor=white)](https://github.com/SukiSU-Ultra/SukiSU-Ultra)
[![ReSukiSU](https://img.shields.io/badge/ReSukiSU-Supported-4CAF50?logo=linux&logoColor=white)](https://github.com/ReSukiSU/ReSukiSU)
[![SUSFS](https://img.shields.io/badge/SUSFS-v2.2.0-FF6D00?logo=gitlab&logoColor=white)](https://gitlab.com/simonpunk/susfs4ksu)

</div>

---

## ⚠️ Disclaimer

> **Your warranty may no longer be valid.**
>
> Flashing a custom kernel always carries a risk of bootloop, data loss, or a bricked device.  
> This builder is experimental — all artifacts are provided **as-is**.
>
> - 💾 **Always back up** your `boot.img` from the **same** ROM / firmware  
> - 🧠 **Read this README** and understand what you are flashing  
> - 🔓 **Unlocked bootloader** is required  
> - 📱 **Poco F5** (`marblein`) and **Redmi Note 12 Turbo** (`marble`) **only**  
> - 🧩 Use a build that matches your **device + ROM** — wrong firmware combos can bootloop  
>
> By flashing these artifacts, **you accept all risk**. The maintainer is not responsible for bricked devices or data loss.

<div align="center">

### 🚨 Proceed at your own risk!

</div>

---

## ✨ Features

| Feature | Description |
|--------|-------------|
| 🧬 **Multi-kernel sources** | Dropdown: Melt (HyperOS), LineageOS, Evolution-X, aosp-pablo, pa-gr (LOS-based) |
| 🤖 **Multi-manager builds** | KernelSU, KernelSU-Next, SukiSU Ultra, ReSukiSU, or a clean no-root baseline |
| 🛡️ **SUSFS integration** | Optional SUSFS (`v2.2.0` / `v2.1.0` / custom) for supported managers |
| 🔗 **Selectable LTO** | `none` · `thin` (default) · `full` — free-runner hardened for thin |
| ⚙️ **GitHub Actions CI** | One-click matrix builds — single manager or parallel multi-manager |
| 📦 **AnyKernel3 packages** | Flashable ZIPs with device checks and automatic boot backup |
| 🔒 **Pinned & verified** | Commit-pinned toolchains, allowlisted managers, policy tests, ZIP attestations |
| 🚀 **Draft releases** | Optional ZIP-only draft release from a successful matrix run |

---

## 📱 Supported Devices

| Device | Codename |
|--------|----------|
| **Poco F5** | `marblein` |
| **Redmi Note 12 Turbo** | `marble` |

> Always flash a build intended for your device and ROM base. Other devices are not supported.

---

## 🏗️ How This Repo Works

Marble uses a **builder + selectable kernel source** model so upstream trees stay clean:

| Repository | Role |
|------------|------|
| [`mohdakil2426/marble-kernel-builder`](https://github.com/mohdakil2426/marble-kernel-builder) | This repo — workflows, scripts, config, packaging |
| Selected kernel source (dropdown) | Clean upstream / fork checked out only in CI — **never patched in-tree** |

### Kernel source presets (workflow dropdown)

Named after the project / author. Pick one in **Build Marble Kernel**:

| Dropdown | Author / project | Source repo | Default ref | ROM family |
|----------|------------------|-------------|-------------|------------|
| `melt` | Melt | [`mohdakil2426/android_kernel_xiaomi_marble`](https://github.com/mohdakil2426/android_kernel_xiaomi_marble) | `melt-rebase` | Stock **HyperOS** |
| `lineageos` | LineageOS | [`LineageOS/android_kernel_xiaomi_sm8450`](https://github.com/LineageOS/android_kernel_xiaomi_sm8450) | `lineage-23.2` | **LOS-based** custom ROMs only |
| `evolution-x` | Evolution-X | [`Evolution-X-Devices/kernel_xiaomi_sm8450`](https://github.com/Evolution-X-Devices/kernel_xiaomi_sm8450) | `cnb` | **LOS-based** custom ROMs only |
| `aosp-pablo` | aosp-pablo | [`aosp-pablo/android_kernel_xiaomi_sm8450`](https://github.com/aosp-pablo/android_kernel_xiaomi_sm8450) | `16` | **LOS-based** custom ROMs only |
| `pa-gr` | pa-gr | [`pa-gr/android_kernel_xiaomi_sm8450`](https://github.com/pa-gr/android_kernel_xiaomi_sm8450) | `vauxite` | **LOS-based** custom ROMs only |

- **HyperOS (`melt`)** uses `marble_defconfig` and Android `clang-r416183b` via `toolchain=auto`.
- **LOS-family kernels** merge `gki_defconfig` + vendor GKI fragments; `toolchain=auto` selects **`llvm-22.1.8`** (armv9). Prefer **`lto=thin`** on free runners.
- Optional **`source_ref`** overrides the preset default branch/tag/commit.

### Recommended workflow inputs

| Preset | toolchain | lto | Notes |
|--------|-----------|-----|-------|
| `melt` | `auto` → `android-r416183b` | `thin` | HyperOS-oriented |
| `lineageos` | `auto` → `llvm-22.1.8` | `thin` | Required for armv9 |
| `evolution-x` | `auto` → `llvm-22.1.8` | `thin` | LOS-family |
| `aosp-pablo` | `auto` → `llvm-22.1.8` | `thin` | LOS-family |
| `pa-gr` | `auto` → `llvm-22.1.8` | `thin` | LOS-family; default `vauxite` has in-tree KernelSU — smoke-test manager apply |

**Free runners:** avoid many parallel LOS+LLVM jobs; prefer 1–2 heavy builds at a time. Prefer `lto=thin`, not `full`.

**After SUSFS kernels:** install a matching SUSFS userspace module (e.g. sidex15) in addition to the manager app.

### Flash ZIP naming

```text
AK3_marble_<FAMILY>_<source>_<manager>[-version][-codeN][_susfs-vX.Y.Z]_rN.zip
```

| FAMILY | Sources |
|--------|---------|
| `MELT` | `melt` |
| `LOS` | `lineageos`, `evolution-x`, `aosp-pablo`, `pa-gr` |

LTO and toolchain are **not** in the filename (see flash banner + `build-info.*`).

**Summaries:** build/matrix summaries include a **Cache** section (Actions ccache/ThinLTO hits + raw `ccache -s`). That block is for CI/artifacts only and is **removed** from draft GitHub Release notes.

**CI flow (simplified):**

```text
Checkout builder → resolve kernel preset
        ↓
Checkout selected kernel source
        ↓
Apply manager + SUSFS (temp workspace only)
        ↓
Compile with pinned toolchain
        ↓
Package AnyKernel3 ZIP + metadata
        ↓
Upload artifacts  ·  optional draft release
```

Patches never land on the source repos — only inside the temporary CI workspace.

**Deep dive:** full CI topology, cache keys, LTO, packaging, and extensibility → [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

---

## 🤖 Manager Matrix

| Manager | Without SUSFS | With SUSFS | Notes |
|---------|:-------------:|:----------:|-------|
| `none` | ✅ | ❌ | Baseline no-root validation build |
| `kernelsu` | ✅ | ❌ | Official only — no compatible SUSFS path yet |
| `kernelsu-next` | ✅ | ✅ | No SUSFS → official `dev` · SUSFS → `pershoot/dev-susfs` |
| `sukisu-ultra` | ✅ | ✅ | No SUSFS → `main` · SUSFS → official `builtin` |
| `resukisu` | ✅ | ✅ | `main` includes built-in manager-side SUSFS |

### Policy

- Only **official upstream** manager repositories are allowlisted at CI time.
- **Exception:** `pershoot/KernelSU-Next@dev-susfs` for KernelSU-Next + SUSFS (CI-proven fork of official `dev`).
- Custom / random forked manager repos are **rejected**.

<details>
<summary><b>Recommended SUSFS manager set</b></summary>

<br/>

For final SUSFS builds, use only:

- `kernelsu-next`
- `sukisu-ultra`
- `resukisu`

Do **not** enable SUSFS with `none` or `kernelsu`.

</details>

---

## ⚙️ Workflows

| Workflow | File | When to use |
|----------|------|-------------|
| **Build Marble Kernel** | [`build-matrix.yml`](.github/workflows/build-matrix.yml) | Build one or many managers · combined summary · optional draft release |
| **Marble Builder Preflight** | [`preflight.yml`](.github/workflows/preflight.yml) | Cheap static checks (shellcheck, actionlint, policy tests) |

### Quick start — build

1. Open **[Actions → Build Marble Kernel → Run workflow](https://github.com/mohdakil2426/marble-kernel-builder/actions)**
2. Choose **kernel source** (`melt` / `lineageos` / `evolution-x` / `aosp-pablo` / `pa-gr`)
3. Select manager checkbox(es)
4. Set **lto** (default `thin`), SUSFS, optional `source_ref`, **toolchain** (LOS → `llvm-22.1.8`), scope
5. Run · download artifacts when green

### Draft release

1. Same workflow as above  
2. Enable **`create_draft_release`**  
3. Release job runs only if **all** selected builds **and** the combined summary pass  
4. Review the **draft** on Releases · publish manually when ready  

> Draft assets contain **only clean flashable ZIPs**.  
> Checksums and build metadata stay in Actions artifacts (used for internal verification).  
> The checkbox is the release gate — no GitHub Environment / Deployment approval is used.

<details>
<summary><b>All workflow inputs</b></summary>

<br/>

| Input | Default | Description |
|-------|---------|-------------|
| `build_none` | `false` | Baseline no-root kernel |
| `build_kernelsu` | `false` | KernelSU (no SUSFS) |
| `build_kernelsu_next` | `false` | KernelSU-Next |
| `build_sukisu_ultra` | `false` | SukiSU Ultra |
| `build_resukisu` | `false` | ReSukiSU |
| `enable_susfs` | `false` | Enable SUSFS for managers that support it |
| `susfs_version` | `v2.2.0` | `v2.2.0` · `v2.1.0` · `custom` |
| `susfs_ref` | *(empty)* | Branch/tag/commit — only with `custom` |
| `kernel_source` | `melt` | Dropdown: `melt` · `lineageos` · `evolution-x` · `aosp-pablo` · `pa-gr` |
| `source_ref` | *(empty)* | Optional branch/tag/commit override (preset default if empty) |
| `build_scope` | `image-only` | `image-only` or `full` |
| `toolchain` | `android-r416183b` | `android-r416183b` (default) or experimental `llvm-22.1.8` |
| `lto` | `thin` | Clang LTO mode: `none` · `thin` (default, free-runner safe) · `full` (needs more RAM) |
| `enable_ccache` | `true` | ccache (4 GiB Melt / 6 GiB LLVM) + ThinLTO Actions cache when `lto=thin` |
| `create_draft_release` | `false` | Create one ZIP-only draft release after a full success |

</details>

---

## 🧪 Safe Build Order

Run in order. Verify each step before the next:

| Step | What to build |
|:----:|---------------|
| **1** | `kernel_source=melt` · `build_none` · `lto=none` or `thin` · `image-only` |
| **2** | Same with one manager · SUSFS **off** |
| **3** | `kernelsu-next` / `sukisu-ultra` / `resukisu` · SUSFS **on** (boot-proven on Melt) |
| **4** | LOS presets · `toolchain=llvm-22.1.8` · `lto=thin` · start with `build_none` |
| **5** | Multi-manager matrix · optional `create_draft_release` |

---

## 📦 Artifacts

### Layout

```text
marble-flash-<label>-<scope>-r<run>/
├─ AK3_marble_<FAMILY>_<source>_<manager>[-version][-codeN][_susfs-vX.Y.Z]_rN.zip
├─ *.zip.sha256
├─ build-info.txt       # resolved refs + workflow metadata
├─ build-info.json      # structured metadata for tooling
├─ summary.md           # CI/artifact summary (includes Cache section)
├─ zip-audit.txt        # structure audit results
└─ ccache-stats.txt     # raw ccache -s (also embedded in summary Cache)
```

### Name examples

```text
AK3_marble_MELT_melt_ksunext-v3.2.0-code33203_susfs-v2.2.0_r121.zip
AK3_marble_LOS_lineageos_ksunext-v3.2.0-code33203_susfs-v2.2.0_r121.zip
AK3_marble_LOS_evolution-x_sukisu-v4.1.3-code40813_susfs-v2.2.0_r122.zip
AK3_marble_LOS_aosp-pablo_resukisu-v4.1.0-code34990_r123.zip
AK3_marble_MELT_melt_noroot_r124.zip
```

> Versioning prefers manager **build version + numeric code**.  
> Fallback: resolved tag → 7-character manager commit. SUSFS off omits the susfs segment.

---

## 🔒 Verified Defaults

Last updated: **2026-07-13** (branch `feature/los-kernel-source-presets`)

| Component | Default / pin |
|-----------|----------------|
| **Kernel source** | `melt` · override via dropdown |
| **LTO** | `thin` (`none` / `full` available) |
| **SUSFS v2.2.0** | `gki-android12-5.10` · `4003ecf2…` |
| **SUSFS v2.1.0** | `gki-android12-5.10` · `86114db0…` |
| **KernelSU** | `tiann/KernelSU@main` · SUSFS disabled |
| **KernelSU-Next** | `KernelSU-Next/KernelSU-Next@dev` |
| **KernelSU-Next + SUSFS** | `pershoot/KernelSU-Next@dev-susfs` |
| **SukiSU Ultra** | `main` / `builtin` (SUSFS) |
| **ReSukiSU** | `ReSukiSU/ReSukiSU@main` |
| **Android Clang** | `clang-r416183b` · commit `6e3223f7…` (Melt default) |
| **LLVM 22.1.8** | Required for LOS armv9 · SHA-256 verified |
| **AnyKernel3** | `dca9dc370838d919d56c1f59ec78b27a14a72c68` |

Full pin table: [`docs/versions.md`](docs/versions.md)

---

## 🛡️ CI Reliability

| Area | Practice |
|------|----------|
| **Actions** | Official actions pinned to immutable commits · Dependabot weekly |
| **Android Clang** | Partial clone + sparse checkout · pinned commit verified before use |
| **LLVM 22.1.8** | Official release only · SHA-256 check · separate cache |
| **ccache** | 4 GiB (Melt) / 6 GiB (LLVM 22) · v4 multi-prefix keys · **LTO** in identity · save on fail (`!cancelled`) |
| **ThinLTO cache** | Separate Actions cache (`~/.cache/thinlto`) when `lto=thin` · save on fail |
| **Policy** | Matrix policy tests once before fan-out |
| **Disk** | Strong SDK cleanup for LTO / low free space (Wild-style) |
| **LTO free-runner** | 16 GiB swap when `lto≠none` · ThinLTO jobs=2 · LLVM JOBS=2 |
| **Artifacts** | Zero recompression · 30-day retention · matrix summary + ccache-stats |
| **Release notes** | Matrix summary **without** CI Cache section |
| **Permissions** | Build jobs `contents: read` · write only on optional release job |
| **Provenance** | OIDC-backed artifact attestations on final ZIPs |
| **Concurrency** | Groups include `kernel_source` + `toolchain` + `lto` + susfs + scope |

<details>
<summary><b>Recent verification</b></summary>

<br/>

**2026-07-13** — feature branch CI (`feature/los-kernel-source-presets`)

- Melt `none` + thin — [29211438837](https://github.com/mohdakil2426/marble-kernel-builder/actions/runs/29211438837)
- LineageOS `none` + thin + llvm — [29212535876](https://github.com/mohdakil2426/marble-kernel-builder/actions/runs/29212535876)
- LineageOS KSUNext+SUSFS + thin — [29214274071](https://github.com/mohdakil2426/marble-kernel-builder/actions/runs/29214274071)

**2026-07-12** — multi-kernel smoke (`build_none`, `image-only`)

- Melt / LineageOS / Evolution-X / aosp-pablo — [29189567468](https://github.com/mohdakil2426/marble-kernel-builder/actions/runs/29189567468) … [29192972075](https://github.com/mohdakil2426/marble-kernel-builder/actions/runs/29192972075)

**2026-06-22** — Melt device boot: KernelSU-Next / SukiSU Ultra / ReSukiSU + SUSFS v2.2.0 (r46–r48)

</details>

---

## 🚀 Flashing Guide

### Prerequisites

- Unlocked bootloader  
- Device: **Poco F5** (`marblein`) or **Redmi Note 12 Turbo** (`marble`)  
- A kernel build that matches your **device + ROM**  
- Stock / original `boot.img` from the **same** ROM/firmware, stored **off-device**  
- Matching manager app for root builds  

### Flash with Kernel Flasher *(recommended)*

1. Download the flashable `.zip`
2. Verify **SHA-256** against the build or release summary
3. Flash to the **active slot** with [Kernel Flasher](https://github.com/fatalcoder524/KernelFlasher/releases)
4. AnyKernel3 will:
   - verify codename (`marble` / `marblein`)
   - **auto-back up** current boot to `/sdcard/marble-kernel-backup/`
5. Reboot · install the matching manager app
6. If SUSFS is enabled: install the [KSU SUSFS module](https://github.com/sidex15/susfs4ksu-module/releases) and configure hiding rules

### Bootloop recovery

Flash the stock `boot.img` from the **same** ROM/firmware back to the active slot.  
On A/B devices, target the correct slot (or both if needed).

---

## 🔗 Resources

| Resource | Link |
|----------|------|
| 📱 Melt / HyperOS kernel | [mohdakil2426/android_kernel_xiaomi_marble](https://github.com/mohdakil2426/android_kernel_xiaomi_marble) |
| 🟠 LineageOS SM8450 | [LineageOS/android_kernel_xiaomi_sm8450](https://github.com/LineageOS/android_kernel_xiaomi_sm8450) |
| 🧬 Evolution-X SM8450 | [Evolution-X-Devices/kernel_xiaomi_sm8450](https://github.com/Evolution-X-Devices/kernel_xiaomi_sm8450) |
| 🧩 aosp-pablo SM8450 | [aosp-pablo/android_kernel_xiaomi_sm8450](https://github.com/aosp-pablo/android_kernel_xiaomi_sm8450) |
| 🧪 pa-gr SM8450 | [pa-gr/android_kernel_xiaomi_sm8450](https://github.com/pa-gr/android_kernel_xiaomi_sm8450) (`vauxite`) |
| 🫙 AnyKernel3 | [osm0sis/AnyKernel3](https://github.com/osm0sis/AnyKernel3) |
| 🔐 KernelSU | [tiann/KernelSU](https://github.com/tiann/KernelSU) |
| 🚀 KernelSU-Next | [KernelSU-Next/KernelSU-Next](https://github.com/KernelSU-Next/KernelSU-Next) |
| 🔀 KSUNext + SUSFS fork | [pershoot/KernelSU-Next](https://github.com/pershoot/KernelSU-Next) (`dev-susfs`) |
| ✨ SukiSU Ultra | [SukiSU-Ultra/SukiSU-Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra) |
| 🔑 ReSukiSU | [ReSukiSU/ReSukiSU](https://github.com/ReSukiSU/ReSukiSU) |
| 🛡️ SUSFS | [simonpunk/susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu) |
| 📦 SUSFS module | [sidex15/susfs4ksu-module](https://github.com/sidex15/susfs4ksu-module) |
| ⚡ Kernel Flasher | [fatalcoder524/KernelFlasher](https://github.com/fatalcoder524/KernelFlasher) |
| 🔥 WildKernels (reference) | [WildKernels/GKI_KernelSU_SUSFS](https://github.com/WildKernels/GKI_KernelSU_SUSFS) |
| 📐 Architecture | [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) |

---

## 🏆 Credits

| Project / person | Contribution |
|------------------|--------------|
| **Kernel source maintainers** | Melt, LineageOS, Evolution-X, aosp-pablo trees used as clean presets |
| **osm0sis** | AnyKernel3 flashing framework |
| **tiann** | KernelSU |
| **KernelSU-Next team** | KernelSU-Next |
| **pershoot** | KernelSU-Next `dev-susfs` integration path |
| **SukiSU Ultra team** | SukiSU Ultra |
| **ReSukiSU team** | ReSukiSU |
| **simonpunk** | susfs4ksu patches |
| **sidex15** | SUSFS userspace module |
| **WildKernels** | Reference CI, LTO/cache, and release patterns |
| Device / ROM communities | HyperOS and LOS-family marble support |

🙏 Special thanks to the open-source community.

---

## 💬 Support

- 🐛 [Open an issue](https://github.com/mohdakil2426/marble-kernel-builder/issues) for builder / CI problems  
- 📖 See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md), [`docs/versions.md`](docs/versions.md), manager matrix, and verification notes  

---

<div align="center">

**⚡ Built with GitHub Actions · for Marble**

<br/>

`marble` · `marblein` · KernelSU family · SUSFS

</div>
