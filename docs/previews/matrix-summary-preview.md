<!--
  Design reference for the combined matrix summary
  (scripts/generate-matrix-summary.sh → matrix-summary.md / release notes).

  Implemented in CI. Keep this file as a human-readable layout sample.
  Sample data mirrors a 3-manager SUSFS matrix (r5-style fixtures).
-->

<div align="center">

<img src="../assets/marble-banner.svg" alt="Marble Kernel" width="720" />

<br/>

# Marble Kernel · Matrix Build

**Combined summary for a successful multi-manager CI run**

`marble` · `marblein` · `image-only`

<br/>

[![Matrix](https://img.shields.io/badge/Matrix-3_managers_passed-4CAF50?logo=githubactions&logoColor=white)](https://github.com/mohdakil2426/marble-kernel-builder/actions/runs/1)
[![LTO](https://img.shields.io/badge/LTO-thin-9C27B0)](#-matrix-configuration)
[![SUSFS](https://img.shields.io/badge/SUSFS-v2.2.0-FF6D00?logo=gitlab&logoColor=white)](https://gitlab.com/simonpunk/susfs4ksu/-/commit/4003ecf2d01c6d13fa8edf6c4f2607365738dc3d)
[![Device](https://img.shields.io/badge/Device-Poco_F5_%2F_RN12_Turbo-EF5350)](https://github.com/mohdakil2426/android_kernel_xiaomi_marble)
[![Scope](https://img.shields.io/badge/Scope-image--only-2088FF)](#-matrix-configuration)

<br/>

🕐 **2026-07-12 09:30:00 UTC** &nbsp;·&nbsp; 🔢 **Run #5** &nbsp;·&nbsp; 🔗 **[View workflow](https://github.com/mohdakil2426/marble-kernel-builder/actions/runs/1)**

</div>

---

## ⚠️ Before you flash

> Custom kernels can bootloop or cause data loss. Artifacts are provided **as-is**.
>
> - 💾 Back up `boot.img` from the **same** ROM / firmware  
> - 🔓 Unlocked bootloader required  
> - 📱 **Poco F5** (`marblein`) or **Redmi Note 12 Turbo** (`marble`) only  
> - 🧩 Match **device + ROM** to the build you flash  
> - ✅ Verify **SHA-256** before flashing  

<div align="center">

### 🚨 Proceed at your own risk

</div>

---

## ⚙️ Matrix configuration

| | |
|:---|:---|
| 📱 **Device** | Poco F5 (`marblein`) · Redmi Note 12 Turbo (`marble`) |
| 🟠 **ROM support** | **Official Xiaomi stock HyperOS only** |
| 👤 **Kernel source** | **Melt** ([`melt`](https://github.com/mohdakil2426/android_kernel_xiaomi_marble)) |
| 🧬 **Kernel base** | `android12-5.10` |
| 🛠️ **Build scope** | `image-only` |
| 🏷️ **Package family** | `MELT` |
| 🔗 **LTO** | `thin` |
| 🧰 **Toolchain** | `android-r416183b` |
| 📦 **Source** | [`melt-rebase @ 3673961`](https://github.com/mohdakil2426/android_kernel_xiaomi_marble/commit/3673961d444b5e2b879be97a161241243d543bd2) |
| 🔨 **Compiler** | `clang-r416183b` · [`6e3223f`](https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+/6e3223f76384455acde43affde3df0ea9df66c0d) |
| 🛡️ **SUSFS** | `v2.2.0` · `gki-android12-5.10` · [`4003ecf`](https://gitlab.com/simonpunk/susfs4ksu/-/commit/4003ecf2d01c6d13fa8edf6c4f2607365738dc3d) |
| ✅ **Result** | **3 / 3** manager builds passed |

---

## 💾 Cache

> CI diagnostics only — this section is **not** included in GitHub Release notes.

| Manager | Actions ccache | Actions ThinLTO |
|:---|:---:|:---:|
| **KernelSU-Next** | `false` | `false` |
| **SukiSU Ultra** | `false` | `false` |
| **ReSukiSU** | `false` | `false` |

### ccache -s — KernelSU-Next

```text
Cacheable calls:   2875 / 4422 (65.02%)
  Hits:             105 / 2875 ( 3.65%)
  Misses:          2770 / 2875 (96.35%)
Local storage:
  Cache size (GB):  0.5 /  6.0 ( 7.71%)
```

---

## 🔑 Managers

| Manager | Version | Code | SUSFS | Status |
|:---|:---|:---:|:---:|:---:|
| **KernelSU-Next** | `v3.2.0` | `33201` | ✅ | ✅ Passed |
| **SukiSU Ultra** | `v4.1.3-b88403d2@HEAD` | `40813` | ✅ | ✅ Passed |
| **ReSukiSU** | `v4.1.0-d0f59d06@ReSukiSU` | `34989` | ✅ | ✅ Passed |

<details>
<summary><b>KernelSU-Next</b> — v3.2.0 · code 33201 · ✅ Passed</summary>

<br/>

| | |
|:---|:---|
| 📁 **Repository** | [`pershoot/KernelSU-Next @ dev-susfs`](https://github.com/pershoot/KernelSU-Next) |
| 🔖 **Version** | `v3.2.0` |
| 🔢 **Version code** | `33201` |
| 🔗 **Commit** | [`5a8a604`](https://github.com/pershoot/KernelSU-Next/commit/5a8a604a9078c2fbfb50e2b0cba87b3a6f4da1c2) |
| 📌 **Note** | Non-SUSFS builds use official `KernelSU-Next/KernelSU-Next@dev` · SUSFS builds use `pershoot/dev-susfs` |
| 📦 **App** | [Manager releases](https://github.com/KernelSU-Next/KernelSU-Next/releases) |

</details>

<details>
<summary><b>SukiSU Ultra</b> — v4.1.3-b88403d2@HEAD · code 40813 · ✅ Passed</summary>

<br/>

| | |
|:---|:---|
| 📁 **Repository** | [`SukiSU-Ultra/SukiSU-Ultra @ builtin`](https://github.com/SukiSU-Ultra/SukiSU-Ultra) |
| 🏷️ **Version name** | `v4.1.3-b88403d2@HEAD` |
| 🔢 **Version code** | `40813` |
| 🔗 **Commit** | [`b88403d`](https://github.com/SukiSU-Ultra/SukiSU-Ultra/commit/b88403d2561b6e00dff84a3c851e630c62f57fd0) |
| 📦 **App** | [Manager releases](https://github.com/SukiSU-Ultra/SukiSU-Ultra/releases) |

</details>

<details>
<summary><b>ReSukiSU</b> — v4.1.0-d0f59d06@ReSukiSU · code 34989 · ✅ Passed</summary>

<br/>

| | |
|:---|:---|
| 📁 **Repository** | [`ReSukiSU/ReSukiSU @ main`](https://github.com/ReSukiSU/ReSukiSU) |
| 🏷️ **Version name** | `v4.1.0-d0f59d06@ReSukiSU` |
| 🔢 **Version code** | `34989` |
| 🔗 **Commit** | [`88e7f51`](https://github.com/ReSukiSU/ReSukiSU/commit/88e7f51c3840436b982276ec35bf2876cfec2713) |
| 📦 **App** | [ReSukiSU](https://github.com/ReSukiSU/ReSukiSU) |

</details>

---

## 🛡️ SUSFS

| | |
|:---|:---|
| 🏷️ **Version** | `v2.2.0` |
| 🌿 **Kernel branch** | `gki-android12-5.10` |
| 🔗 **Commit** | [`4003ecf`](https://gitlab.com/simonpunk/susfs4ksu/-/commit/4003ecf2d01c6d13fa8edf6c4f2607365738dc3d) |
| 📦 **Userspace module** | [sidex15/susfs4ksu-module](https://github.com/sidex15/susfs4ksu-module/releases) |

> After boot: install the SUSFS module matching this version, configure hiding rules, then reboot.

---

## 📦 Artifacts & checksums

| Manager | File | Size | SHA-256 |
|:---|:---|:---:|:---|
| KernelSU-Next | `AK3_marble_MELT_melt_ksunext-v3.2.0-code33201_susfs-v2.2.0_r5.zip` | *sample* | `…` *(computed at build time)* |
| SukiSU Ultra | `AK3_marble_MELT_melt_sukisu-v4.1.3-b88403d2-code40813_susfs-v2.2.0_r5.zip` | *sample* | `…` *(computed at build time)* |
| ReSukiSU | `AK3_marble_MELT_melt_resukisu-v4.1.0-d0f59d06-code34989_susfs-v2.2.0_r5.zip` | *sample* | `…` *(computed at build time)* |

> In production, **Size** and **SHA-256** are filled from the real ZIPs.

---

## 📲 Installation

<details>
<summary><b>Prerequisites</b></summary>

<br/>

- 🔓 Unlocked bootloader  
- 📱 Poco F5 (`marblein`) or Redmi Note 12 Turbo (`marble`) only  
- 🧩 Kernel build that matches your **device + ROM**  
- 💾 Original `boot.img` from the same ROM/firmware stored **off-device**  
- 📦 Matching manager app for the ZIP you flash  
- 🛡️ [KSU SUSFS module](https://github.com/sidex15/susfs4ksu-module/releases) if this matrix enabled SUSFS  

</details>

<details>
<summary><b>Flash steps</b> (Kernel Flasher recommended)</summary>

<br/>

1. Download the ZIP for **one** manager  
2. Verify **SHA-256** against the table above  
3. Flash to the **active slot** with [Kernel Flasher](https://github.com/fatalcoder524/KernelFlasher/releases)  
4. AnyKernel3 will verify codename (`marble` / `marblein`) and **auto-back up** boot to `/sdcard/marble-kernel-backup/`  
5. Reboot · install / open the matching manager app  
6. If SUSFS is enabled: install the SUSFS module, configure rules, reboot  

</details>

> [!WARNING]
> **Bootloop?** Flash the original `boot.img` from the same ROM/firmware back to the active slot (Kernel Flasher or fastboot). Keep that backup accessible **before** you flash.

---

## 🙏 Credits

| | |
|:---|:---|
| 🧑‍💻 **Kernel source** | [Melt](https://github.com/mohdakil2426/android_kernel_xiaomi_marble) (`mohdakil2426/android_kernel_xiaomi_marble`) |
| 📦 **AnyKernel3** | [osm0sis/AnyKernel3](https://github.com/osm0sis/AnyKernel3) |
| 🔑 **KernelSU-Next** | [`pershoot/KernelSU-Next`](https://github.com/pershoot/KernelSU-Next) |
| 🔑 **SukiSU Ultra** | [`SukiSU-Ultra/SukiSU-Ultra`](https://github.com/SukiSU-Ultra/SukiSU-Ultra) |
| 🔑 **ReSukiSU** | [`ReSukiSU/ReSukiSU`](https://github.com/ReSukiSU/ReSukiSU) |
| 🛡️ **SUSFS** | [simonpunk/susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu) |

---

<div align="center">

**⚡ Built with GitHub Actions · for Marble**

<br/>

`marble` · `marblein` · KernelSU family · SUSFS

<br/>

*Preview design — not live CI output*

</div>
