#!/usr/bin/env bash
set -euo pipefail

source config/marble.env
source scripts/lib/summary-common.sh

KERNEL_DIR="${KERNEL_DIR:-kernel-source}"
MANAGER="${MANAGER:-none}"
ENABLE_SUSFS="${ENABLE_SUSFS:-false}"
BUILD_SCOPE="${BUILD_SCOPE:-image-only}"

release_dir="${KERNEL_DIR}/${RELEASE_DIR}"
build_info="${release_dir}/build-info.txt"
zip_env="${release_dir}/zip-name.env"
summary="${release_dir}/summary.md"

if [[ ! -f "${build_info}" || ! -f "${zip_env}" ]]; then
  echo "::error::Missing build metadata for summary generation"
  exit 1
fi

source "${zip_env}"

get_info() {
  local key="$1"
  summary_get_info "${build_info}" "${key}"
}

# ── Pull all fields from build-info.txt ──────────────────────────────────────
source_repo="$(get_info source_repo)"
source_ref="$(get_info source_ref)"
source_commit="$(get_info source_commit)"
workflow_run="$(get_info workflow_run)"
kernel_source_id="$(get_info kernel_source)"
kernel_source_author="$(get_info kernel_source_author)"
rom_support="$(get_info rom_support)"
if [[ -z "${rom_support}" ]]; then
  rom_support="Official Xiaomi stock ${SUPPORTED_ROM_LABEL} only"
fi
manager_name="$(get_info manager)"
manager_repo="$(get_info manager_repo)"
manager_ref="$(get_info manager_ref)"
manager_commit="$(get_info manager_commit)"
manager_tag="$(get_info manager_tag)"
manager_version_code="$(get_info manager_version_code)"
manager_build_version_code="$(get_info manager_build_version_code)"
manager_build_version_name="$(get_info manager_build_version_name)"
manager_build_tag="$(get_info manager_build_tag)"
manager_signature_size="$(get_info manager_signature_size)"
manager_signature_hash="$(get_info manager_signature_hash)"
manager_supported_line="$(get_info manager_supported_line)"
susfs_version="$(get_info susfs_version)"
susfs_branch="$(get_info susfs_kernel_branch)"
susfs_commit="$(get_info susfs_commit)"
susfs_reported="$(get_info susfs_reported_version)"
susfs_url="$(get_info susfs_url)"
android_clang_version="$(get_info android_clang_version)"
android_clang_commit="$(get_info android_clang_commit)"
lto_mode="$(get_info lto)"
lto_mode="${lto_mode:-thin}"
toolchain_id="$(get_info toolchain)"
ccache_hit="$(get_info ccache_hit)"
thinlto_cache_hit="$(get_info thinlto_cache_hit)"
package_family="$(get_info package_family)"
quality_label="$(get_info quality_label)"
if [[ -z "${quality_label}" ]]; then
  quality_label="$(summary_quality_label "${kernel_source_id:-melt}")"
fi
zip_sha="$(sha256sum "${release_dir}/${zip_name}" | awk '{print $1}')"
image_sha="$(sha256sum "${release_dir}/Image" | awk '{print $1}')"
zip_size="$(du -h "${release_dir}/${zip_name}" | awk '{print $1}')"
build_date="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
build_id="${GITHUB_RUN_ID:-}"
run_number="${GITHUB_RUN_NUMBER:-}"
if [[ -z "${build_id}" && -n "${workflow_run}" ]]; then
  build_id="${workflow_run##*/}"
fi

# ── Display names ─────────────────────────────────────────────────────────────
manager_display="$(manager_display "${manager_name}")"

susfs_display="${susfs_reported:-${susfs_version}}"

manager_app_url="$(manager_app_url "${manager_name}")"

# ── Build shields.io badge URLs ───────────────────────────────────────────────

# Manager badge
if [[ "${manager_name}" == "none" ]]; then
  manager_badge_url="https://img.shields.io/badge/Manager-No_Root-757575?style=for-the-badge&logo=linux&logoColor=white"
  manager_badge_link="https://github.com/${source_repo}"
else
  _label="$(badge_encode "${manager_display}")"
  _version_str="${manager_build_version_name:-${manager_build_tag:-${manager_tag:-unknown}}}"
  _version_code="${manager_build_version_code:-${manager_version_code}}"
  if [[ -n "${_version_code}" ]]; then
    _version_str="${_version_str} #${_version_code}"
  fi
  _msg="$(badge_encode "${_version_str}")"
  manager_badge_url="https://img.shields.io/badge/${_label}-${_msg}-4CAF50?style=for-the-badge&logo=linux&logoColor=white"
  manager_badge_link="https://github.com/${manager_repo}"
fi

# SUSFS badge
if [[ "${ENABLE_SUSFS}" == "true" ]]; then
  _msg="$(badge_encode "${susfs_display}")"
  susfs_badge_url="https://img.shields.io/badge/SUSFS-${_msg}-FF6D00?style=for-the-badge&logo=gitlab&logoColor=white"
  susfs_badge_link="${susfs_url}"
else
  susfs_badge_url="https://img.shields.io/badge/SUSFS-Disabled-757575?style=for-the-badge&logo=gitlab&logoColor=white"
  susfs_badge_link="https://gitlab.com/simonpunk/susfs4ksu"
fi

device_badge_url="https://img.shields.io/badge/Poco_F5_%2F_Note_12_Turbo-marble_%7C_marblein-EF5350?style=for-the-badge"
build_badge_url="https://img.shields.io/badge/Build-Passing-2088FF?style=for-the-badge&logo=githubactions&logoColor=white"

# ── Write summary ─────────────────────────────────────────────────────────────
{
  # ── Centered header with badges ──────────────────────────────────────────
  echo '<div align="center">'
  echo
  echo "# 🪨 Marble Kernel"
  echo
  echo "### Poco F5 · Redmi Note 12 Turbo"
  echo
  echo "[![Manager](${manager_badge_url})](${manager_badge_link})"
  echo "[![SUSFS](${susfs_badge_url})](${susfs_badge_link})"
  echo "[![Device](${device_badge_url})](https://github.com/${source_repo})"
  echo "[![Build](${build_badge_url})](${workflow_run})"
  echo
  echo "<br>"
  echo
  echo "🕐 **${build_date}** &nbsp;·&nbsp; 🔢 **Run #${run_number:-${build_id}}** &nbsp;·&nbsp; 🔗 **[View Workflow](${workflow_run})**"
  echo
  echo '</div>'
  echo
  echo "---"
  echo

  # ── Build Configuration ──────────────────────────────────────────────────
  echo "## ⚙️ Build Configuration"
  echo
  echo "| | |"
  echo "|:---|:---|"
  echo "| 📱 **Device** | Poco F5 (\`marblein\`) · Redmi Note 12 Turbo (\`marble\`) |"
  echo "| 🟠 **ROM Support** | **${rom_support}** |"
  if [[ -n "${kernel_source_author}" || -n "${kernel_source_id}" ]]; then
    _ks_label="${kernel_source_author:-${kernel_source_id}}"
    _ks_id="${kernel_source_id:-unknown}"
    if [[ -n "${source_repo}" ]]; then
      echo "| 👤 **Kernel Source** | **${_ks_label}** ([\`${_ks_id}\`](https://github.com/${source_repo})) |"
    else
      echo "| 👤 **Kernel Source** | **${_ks_label}** (\`${_ks_id}\`) |"
    fi
  fi
  echo "| 🧬 **Kernel Base** | \`android12-5.10\` |"
  echo "| 🛠️ **Build Scope** | \`${BUILD_SCOPE}\` |"
  if [[ -n "${package_family}" ]]; then
    echo "| 🏷️ **Package Family** | \`${package_family}\` |"
  fi
  echo "| 🧪 **Quality** | \`${quality_label}\` |"
  echo "| 🔗 **LTO** | \`${lto_mode}\` |"
  if [[ -n "${toolchain_id}" ]]; then
    echo "| 🧰 **Toolchain** | \`${toolchain_id}\` |"
  fi
  echo "| 📦 **Source** | [\`${source_ref} @ $(short_commit "${source_commit}")\`](https://github.com/${source_repo}/commit/${source_commit}) |"
  echo "| 🔨 **Compiler** | \`${android_clang_version:-clang-r416183b}\` |"
  if [[ -n "${android_clang_commit}" ]]; then
    echo "| 🧷 **Compiler Commit** | \`$(short_commit "${android_clang_commit}")\` |"
  fi
  echo
  echo "---"
  echo

  # ── Cache (CI only — stripped from GitHub Release notes) ──────────────────
  summary_emit_cache_section \
    "${ccache_hit:-unknown}" \
    "${thinlto_cache_hit:-n/a}" \
    "${release_dir}/ccache-stats.txt"
  echo "---"
  echo

  # ── Manager ──────────────────────────────────────────────────────────────
  if [[ "${manager_name}" == "none" ]]; then
    echo "## 🔑 Manager — Baseline (No Root)"
    echo
    echo "No root manager integrated. This is a vanilla kernel build for testing and baseline comparison."
  else
    echo "## 🔑 Manager — ${manager_display}"
    echo
    echo "| | |"
    echo "|:---|:---|"
    echo "| 📁 **Repository** | [\`${manager_repo} @ ${manager_ref}\`](https://github.com/${manager_repo}) |"
    if [[ -n "${manager_build_version_name}" ]]; then
      echo "| 🏷️ **Version Name** | \`${manager_build_version_name}\` |"
    fi
    if [[ -n "${manager_build_tag:-${manager_tag}}" && -n "${manager_build_version_code:-${manager_version_code}}" ]]; then
      echo "| 🔖 **Version** | \`${manager_build_tag:-${manager_tag}}\` &nbsp;·&nbsp; code \`${manager_build_version_code:-${manager_version_code}}\` |"
    elif [[ -n "${manager_build_tag:-${manager_tag}}" ]]; then
      echo "| 🔖 **Version** | \`${manager_build_tag:-${manager_tag}}\` |"
    elif [[ -n "${manager_build_version_code:-${manager_version_code}}" ]]; then
      echo "| 🔢 **Version Code** | \`${manager_build_version_code:-${manager_version_code}}\` |"
    fi
    echo "| 🔗 **Commit** | [\`$(short_commit "${manager_commit}")\`](https://github.com/${manager_repo}/commit/${manager_commit}) |"
    if [[ -n "${manager_signature_size}" ]]; then
      echo "| ✍️ **Signature Size** | \`${manager_signature_size}\` |"
    fi
    if [[ -n "${manager_signature_hash}" ]]; then
      echo "| 🧾 **Signature Hash** | \`${manager_signature_hash}\` |"
    fi
    if [[ -n "${manager_supported_line}" ]]; then
      echo "| 🤝 **Supported Managers** | ${manager_supported_line//,/, } |"
    fi
    if [[ "${manager_name}" == "kernelsu-next" && "${ENABLE_SUSFS}" == "true" ]]; then
      echo "| 📌 **Note** | Non-SUSFS builds use official \`KernelSU-Next/KernelSU-Next@dev\` · SUSFS builds use \`pershoot/dev-susfs\` |"
    fi
  fi
  echo
  echo "---"
  echo

  # ── SUSFS ────────────────────────────────────────────────────────────────
  echo "## 🛡️ SUSFS"
  echo
  if [[ "${ENABLE_SUSFS}" == "true" ]]; then
    echo "| | |"
    echo "|:---|:---|"
    echo "| 🏷️ **Version** | \`${susfs_display}\` |"
    echo "| 🌿 **Kernel Branch** | \`${susfs_branch}\` |"
    echo "| 🔗 **Commit** | [\`$(short_commit "${susfs_commit}")\`](${susfs_url}) |"
    echo
    summary_susfs_module_note
  else
    echo "SUSFS is not enabled for this build."
  fi
  echo
  echo "---"
  echo

  # ── Installation ─────────────────────────────────────────────────────────
  echo "## 📲 Installation"
  echo
  echo "<details>"
  echo "<summary><b>📋 Prerequisites</b> — expand before flashing</summary>"
  echo "<br>"
  echo
  echo "- 🔓 Unlocked bootloader"
  echo "- 📱 Poco F5 (\`marblein\`) or Redmi Note 12 Turbo (\`marble\`) **only**"
  echo "- 🟠 **${rom_support}** — flash only on a matching ROM family"
  echo "- 💾 Stock \`boot.img\` from the **same ROM/firmware** stored safely outside the device"
  if [[ "${manager_name}" != "none" && -n "${manager_app_url}" ]]; then
    echo "- 📦 [${manager_display} manager app](${manager_app_url})"
  fi
  if [[ "${ENABLE_SUSFS}" == "true" ]]; then
    echo "- 🧩 [KSU SUSFS module](https://github.com/sidex15/susfs4ksu-module/releases) matching \`${susfs_display}\`"
  fi
  echo
  echo "</details>"
  echo
  echo "<details>"
  echo "<summary><b>⚡ Flash Steps</b></summary>"
  echo "<br>"
  echo
  echo "1. Download \`${zip_name}\`"
  echo "2. Verify it against the SHA256 shown in this summary before flashing"
  echo "3. Flash the ZIP to the active slot via **[Kernel Flasher](https://github.com/fatalcoder524/KernelFlasher/releases)**"
  echo "4. The AnyKernel3 installer will verify your device codename and **automatically back up** your current boot image to \`/sdcard/marble-kernel-backup/\` before writing"
  if [[ "${manager_name}" != "none" ]]; then
    echo "5. After boot — install / open the **${manager_display}** manager app"
  fi
  if [[ "${ENABLE_SUSFS}" == "true" ]]; then
    echo "6. Install the **KSU SUSFS module**, configure hiding rules, then reboot"
  fi
  echo
  echo "</details>"
  echo
  echo "> [!WARNING]"
  echo "> **Bootloop?** Flash the stock \`boot.img\` back to the active slot using Kernel Flasher or fastboot. Keep it accessible before flashing."
  echo
  echo "---"
  echo

  # ── Artifacts & Checksums ────────────────────────────────────────────────
  echo "## 📦 Artifacts & Checksums"
  echo
  echo "| File | Size | Notes |"
  echo "|:---|:---:|:---|"
  echo "| \`${zip_name}\` | ${zip_size} | Flashable AnyKernel3 zip |"
  echo "| \`${zip_name}.sha256\` | — | SHA256 checksum |"
  echo "| \`build-info.txt\` | — | Exact resolved refs + workflow metadata |"
  echo
  echo "<details>"
  echo "<summary><b>🔐 SHA256 Checksums</b></summary>"
  echo "<br>"
  echo
  echo "| Artifact | SHA256 |"
  echo "|:---|:---|"
  echo "| \`Image\` | \`${image_sha}\` |"
  echo "| \`.zip\` | \`${zip_sha}\` |"
  echo
  echo "</details>"
  echo
  echo "---"
  echo

  # ── Credits (dynamic from build-info — no hardcoded maintainer names) ────
  echo "## 🙏 Credits"
  echo
  echo "| | |"
  echo "|:---|:---|"
  credit_author="${kernel_source_author:-${kernel_source_id:-kernel}}"
  if [[ -n "${source_repo}" ]]; then
    echo "| 🧑‍💻 **Kernel source** | [${credit_author}](https://github.com/${source_repo}) (\`${source_repo}\`) |"
  else
    echo "| 🧑‍💻 **Kernel source** | ${credit_author} |"
  fi
  echo "| 📦 **AnyKernel3** | [osm0sis/AnyKernel3](https://github.com/osm0sis/AnyKernel3) |"
  if [[ "${manager_name}" != "none" && -n "${manager_repo}" ]]; then
    echo "| 🔑 **${manager_display}** | [\`${manager_repo}\`](https://github.com/${manager_repo}) |"
  elif [[ "${manager_name}" != "none" ]]; then
    echo "| 🔑 **${manager_display}** | ${manager_display} |"
  fi
  if [[ "${ENABLE_SUSFS}" == "true" ]]; then
    echo "| 🛡️ **SUSFS** | [simonpunk/susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu) |"
  fi
  echo
  echo "---"
  echo
  echo '<div align="center">'
  echo
  echo "⚡ Built with ❤️ using **GitHub Actions**"
  echo
  echo '</div>'
} > "${summary}"

cat "${summary}"
