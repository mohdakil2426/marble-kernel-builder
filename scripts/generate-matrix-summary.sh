#!/usr/bin/env bash
set -euo pipefail

source config/marble.env
source scripts/lib/summary-common.sh

MATRIX_ARTIFACTS_DIR="${MATRIX_ARTIFACTS_DIR:-matrix-artifacts}"
MATRIX_SUMMARY="${MATRIX_SUMMARY:-matrix-summary.md}"
BUILD_SCOPE="${BUILD_SCOPE:-image-only}"

if [[ ! -d "${MATRIX_ARTIFACTS_DIR}" ]]; then
  echo "::error::Matrix artifacts directory not found: ${MATRIX_ARTIFACTS_DIR}"
  exit 1
fi

artifact_dirs=()
if [[ -f "${MATRIX_ARTIFACTS_DIR}/build-info.txt" && -f "${MATRIX_ARTIFACTS_DIR}/zip-name.env" ]]; then
  artifact_dirs+=("${MATRIX_ARTIFACTS_DIR}")
fi

mapfile -t nested_artifact_dirs < <(
  find "${MATRIX_ARTIFACTS_DIR}" -mindepth 1 -maxdepth 1 -type d | sort
)
artifact_dirs+=("${nested_artifact_dirs[@]}")

valid_dirs=()
for artifact_dir in "${artifact_dirs[@]}"; do
  if [[ -f "${artifact_dir}/build-info.txt" && -f "${artifact_dir}/zip-name.env" ]]; then
    valid_dirs+=("${artifact_dir}")
  fi
done
artifact_dirs=("${valid_dirs[@]}")

if [[ "${#artifact_dirs[@]}" -eq 0 ]]; then
  echo "::error::No matrix flash artifact metadata found in ${MATRIX_ARTIFACTS_DIR}"
  exit 1
fi

get_info() {
  local file="$1"
  local key="$2"
  summary_get_info "${file}" "${key}"
}

manager_version_label() {
  local build_info="$1"
  local tag build_tag build_name build_code static_code commit
  tag="$(get_info "${build_info}" manager_tag)"
  build_tag="$(get_info "${build_info}" manager_build_tag)"
  build_name="$(get_info "${build_info}" manager_build_version_name)"
  build_code="$(get_info "${build_info}" manager_build_version_code)"
  static_code="$(get_info "${build_info}" manager_version_code)"
  commit="$(get_info "${build_info}" manager_commit)"

  local version="${build_name:-${build_tag:-${tag:-}}}"
  if [[ -z "${version}" && -n "${commit}" ]]; then
    version="$(short_commit "${commit}")"
  fi
  if [[ -n "${build_code:-${static_code}}" ]]; then
    echo "${version:-unknown} · code ${build_code:-${static_code}}"
  else
    echo "${version:-unknown}"
  fi
}

manager_version_only() {
  local build_info="$1"
  local tag build_tag build_name commit
  tag="$(get_info "${build_info}" manager_tag)"
  build_tag="$(get_info "${build_info}" manager_build_tag)"
  build_name="$(get_info "${build_info}" manager_build_version_name)"
  commit="$(get_info "${build_info}" manager_commit)"
  local version="${build_name:-${build_tag:-${tag:-}}}"
  if [[ -z "${version}" && -n "${commit}" ]]; then
    version="$(short_commit "${commit}")"
  fi
  echo "${version:-unknown}"
}

manager_code_only() {
  local build_info="$1"
  local build_code static_code
  build_code="$(get_info "${build_info}" manager_build_version_code)"
  static_code="$(get_info "${build_info}" manager_version_code)"
  echo "${build_code:-${static_code:-—}}"
}

first_info="${artifact_dirs[0]}/build-info.txt"
if [[ ! -f "${first_info}" ]]; then
  echo "::error::Missing build-info.txt in ${artifact_dirs[0]}"
  exit 1
fi

source_repo="$(get_info "${first_info}" source_repo)"
source_ref="$(get_info "${first_info}" source_ref)"
source_commit="$(get_info "${first_info}" source_commit)"
workflow_run="$(get_info "${first_info}" workflow_run)"
susfs_reported="$(get_info "${first_info}" susfs_reported_version)"
susfs_version="$(get_info "${first_info}" susfs_version)"
susfs_branch="$(get_info "${first_info}" susfs_kernel_branch)"
susfs_commit="$(get_info "${first_info}" susfs_commit)"
susfs_url="$(get_info "${first_info}" susfs_url)"
android_clang_version="$(get_info "${first_info}" android_clang_version)"
android_clang_commit="$(get_info "${first_info}" android_clang_commit)"
toolchain_id="$(get_info "${first_info}" toolchain)"
lto_mode="$(get_info "${first_info}" lto)"
lto_mode="${lto_mode:-thin}"
package_family="$(get_info "${first_info}" package_family)"
enable_susfs_first="$(get_info "${first_info}" enable_susfs)"
build_date="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
run_number="${SOURCE_RUN_NUMBER:-${GITHUB_RUN_NUMBER:-}}"
susfs_display="${susfs_reported:-${susfs_version}}"

manager_count="${#artifact_dirs[@]}"
builder_repo="${GITHUB_REPOSITORY:-mohdakil2426/marble-kernel-builder}"
banner_ref="${GITHUB_SHA:-main}"
banner_url="https://raw.githubusercontent.com/${builder_repo}/${banner_ref}/docs/assets/marble-banner.svg"

manager_badge_url="https://img.shields.io/badge/Matrix-${manager_count}_managers_passed-4CAF50?logo=githubactions&logoColor=white"
if [[ "${enable_susfs_first}" == "true" && -n "${susfs_display}" ]]; then
  susfs_badge_url="https://img.shields.io/badge/SUSFS-$(badge_encode "${susfs_display}")-FF6D00?logo=gitlab&logoColor=white"
else
  susfs_badge_url="https://img.shields.io/badge/SUSFS-Disabled-757575?logo=gitlab&logoColor=white"
fi
device_badge_url="https://img.shields.io/badge/Device-Poco_F5_%2F_RN12_Turbo-EF5350"
scope_badge_url="https://img.shields.io/badge/Scope-$(badge_encode "${BUILD_SCOPE}")-2088FF"
lto_badge_url="https://img.shields.io/badge/LTO-$(badge_encode "${lto_mode}")-9C27B0"

{
  echo '<div align="center">'
  echo
  echo "<img src=\"${banner_url}\" alt=\"Marble Kernel\" width=\"720\" />"
  echo
  echo "<br/>"
  echo
  echo "# Marble Kernel · Matrix Build"
  echo
  echo "**Combined summary for a successful multi-manager CI run**"
  echo
  echo "\`marble\` · \`marblein\` · \`${BUILD_SCOPE}\`"
  echo
  echo "<br/>"
  echo
  echo "[![Matrix](${manager_badge_url})](${workflow_run})"
  echo "[![LTO](${lto_badge_url})](${workflow_run})"
  echo "[![SUSFS](${susfs_badge_url})](${susfs_url:-https://gitlab.com/simonpunk/susfs4ksu})"
  echo "[![Device](${device_badge_url})](https://github.com/${source_repo})"
  echo "[![Scope](${scope_badge_url})](${workflow_run})"
  echo
  echo "<br/>"
  echo
  echo "🕐 **${build_date}** &nbsp;·&nbsp; 🔢 **Run #${run_number:-unknown}** &nbsp;·&nbsp; 🔗 **[View workflow](${workflow_run})**"
  echo
  echo '</div>'
  echo
  echo "---"
  echo
  echo "## ⚠️ Before you flash"
  echo
  echo "> Custom kernels can bootloop or cause data loss. Artifacts are provided **as-is**."
  echo ">"
  echo "> - 💾 Back up \`boot.img\` from the **same** ROM / firmware"
  echo "> - 🔓 Unlocked bootloader required"
  echo "> - 📱 **Poco F5** (\`marblein\`) or **Redmi Note 12 Turbo** (\`marble\`) only"
  echo "> - 🧩 Match **device + ROM** to the build you flash"
  echo "> - ✅ Verify **SHA-256** before flashing"
  echo
  echo '<div align="center">'
  echo
  echo "### 🚨 Proceed at your own risk"
  echo
  echo '</div>'
  echo
  echo "---"
  echo
  echo "## ⚙️ Matrix configuration"
  echo
  echo "| | |"
  echo "|:---|:---|"
  kernel_source_id="$(get_info "${first_info}" kernel_source)"
  kernel_source_author="$(get_info "${first_info}" kernel_source_author)"
  rom_support="$(get_info "${first_info}" rom_support)"
  echo "| 📱 **Device** | Poco F5 (\`marblein\`) · Redmi Note 12 Turbo (\`marble\`) |"
  if [[ -n "${rom_support}" ]]; then
    echo "| 🟠 **ROM support** | **${rom_support}** |"
  fi
  if [[ -n "${kernel_source_author}" || -n "${kernel_source_id}" ]]; then
    _ks_label="${kernel_source_author:-${kernel_source_id}}"
    _ks_id="${kernel_source_id:-unknown}"
    if [[ -n "${source_repo}" ]]; then
      echo "| 👤 **Kernel source** | **${_ks_label}** ([\`${_ks_id}\`](https://github.com/${source_repo})) |"
    else
      echo "| 👤 **Kernel source** | **${_ks_label}** (\`${_ks_id}\`) |"
    fi
  fi
  echo "| 🧬 **Kernel base** | \`android12-5.10\` |"
  echo "| 🛠️ **Build scope** | \`${BUILD_SCOPE}\` |"
  if [[ -n "${package_family}" ]]; then
    echo "| 🏷️ **Package family** | \`${package_family}\` |"
  fi
  echo "| 🔗 **LTO** | \`${lto_mode}\` |"
  if [[ -n "${toolchain_id}" ]]; then
    echo "| 🧰 **Toolchain** | \`${toolchain_id}\` |"
  fi
  echo "| 📦 **Source** | [\`${source_ref} @ $(short_commit "${source_commit}")\`](https://github.com/${source_repo}/commit/${source_commit}) |"
  echo "| 🔨 **Compiler** | \`${android_clang_version:-clang-r416183b}\` |"
  if [[ -n "${android_clang_commit}" ]]; then
    echo "| 🧷 **Compiler commit** | \`$(short_commit "${android_clang_commit}")\` |"
  fi
  if [[ "${enable_susfs_first}" == "true" && -n "${susfs_display}" ]]; then
    echo "| 🛡️ **SUSFS** | \`${susfs_display}\` · \`${susfs_branch}\` · [\`$(short_commit "${susfs_commit}")\`](${susfs_url}) |"
  else
    echo "| 🛡️ **SUSFS** | Disabled |"
  fi
  echo "| ✅ **Result** | **${manager_count} / ${manager_count}** manager builds passed |"
  echo
  echo "---"
  echo

  # ── Cache (CI only — stripped from GitHub Release notes) ──────────────────
  {
    echo "${SUMMARY_CACHE_START}"
    echo "## 💾 Cache"
    echo
    echo "> CI diagnostics only — this section is **not** included in GitHub Release notes."
    echo
    echo "| Manager | Actions ccache | Actions ThinLTO |"
    echo "|:---|:---:|:---:|"
    for artifact_dir in "${artifact_dirs[@]}"; do
      build_info="${artifact_dir}/build-info.txt"
      [[ -f "${build_info}" ]] || continue
      m_name="$(get_info "${build_info}" manager)"
      m_display="$(manager_display "${m_name}")"
      m_ccache="$(get_info "${build_info}" ccache_hit)"
      m_thin="$(get_info "${build_info}" thinlto_cache_hit)"
      echo "| **${m_display}** | \`${m_ccache:-unknown}\` | \`${m_thin:-n/a}\` |"
    done
    echo
    # Embed default ccache -s text (same as ccache-stats.txt artifact) per manager.
    for artifact_dir in "${artifact_dirs[@]}"; do
      build_info="${artifact_dir}/build-info.txt"
      stats_file="${artifact_dir}/ccache-stats.txt"
      [[ -f "${build_info}" ]] || continue
      m_name="$(get_info "${build_info}" manager)"
      m_display="$(manager_display "${m_name}")"
      echo "### ccache -s — ${m_display}"
      echo
      echo '```text'
      if [[ -f "${stats_file}" ]]; then
        cat "${stats_file}"
      else
        echo "(ccache-stats.txt not available)"
      fi
      echo '```'
      echo
    done
    echo "${SUMMARY_CACHE_END}"
  }
  echo "---"
  echo
  echo "## 🔑 Managers"
  echo
  echo "| Manager | Version | Code | SUSFS | Status |"
  echo "|:---|:---|:---:|:---:|:---:|"
  for artifact_dir in "${artifact_dirs[@]}"; do
    build_info="${artifact_dir}/build-info.txt"
    [[ -f "${build_info}" ]] || continue
    manager_name="$(get_info "${build_info}" manager)"
    display="$(manager_display "${manager_name}")"
    version_cell="$(manager_version_only "${build_info}")"
    code_cell="$(manager_code_only "${build_info}")"
    enable_susfs="$(get_info "${build_info}" enable_susfs)"
    if [[ "${enable_susfs}" == "true" ]]; then
      susfs_cell="✅"
    else
      susfs_cell="—"
    fi
    echo "| **${display}** | \`${version_cell}\` | \`${code_cell}\` | ${susfs_cell} | ✅ Passed |"
  done
  echo

  for artifact_dir in "${artifact_dirs[@]}"; do
    build_info="${artifact_dir}/build-info.txt"
    zip_env="${artifact_dir}/zip-name.env"
    [[ -f "${build_info}" && -f "${zip_env}" ]] || continue
    # shellcheck disable=SC1090
    source "${zip_env}"

    manager_name="$(get_info "${build_info}" manager)"
    display="$(manager_display "${manager_name}")"
    version_label="$(manager_version_label "${build_info}")"
    manager_repo="$(get_info "${build_info}" manager_repo)"
    manager_ref="$(get_info "${build_info}" manager_ref)"
    manager_commit="$(get_info "${build_info}" manager_commit)"
    build_code="$(get_info "${build_info}" manager_build_version_code)"
    static_code="$(get_info "${build_info}" manager_version_code)"
    build_name="$(get_info "${build_info}" manager_build_version_name)"
    build_tag="$(get_info "${build_info}" manager_build_tag)"
    tag="$(get_info "${build_info}" manager_tag)"
    sig_size="$(get_info "${build_info}" manager_signature_size)"
    sig_hash="$(get_info "${build_info}" manager_signature_hash)"
    supported_line="$(get_info "${build_info}" manager_supported_line)"
    app_url="$(manager_app_url "${manager_name}")"

    echo "<details>"
    echo "<summary><b>${display}</b> — ${version_label} · ✅ Passed</summary>"
    echo
    echo "<br/>"
    echo
    echo "| | |"
    echo "|:---|:---|"
    if [[ -n "${manager_repo}" ]]; then
      echo "| 📁 **Repository** | [\`${manager_repo} @ ${manager_ref}\`](https://github.com/${manager_repo}) |"
    fi
    if [[ -n "${build_name}" ]]; then
      echo "| 🏷️ **Version name** | \`${build_name}\` |"
    fi
    if [[ -n "${build_tag:-${tag}}" ]]; then
      echo "| 🔖 **Version** | \`${build_tag:-${tag}}\` |"
    fi
    if [[ -n "${build_code:-${static_code}}" ]]; then
      echo "| 🔢 **Version code** | \`${build_code:-${static_code}}\` |"
    fi
    if [[ -n "${manager_repo}" && -n "${manager_commit}" ]]; then
      echo "| 🔗 **Commit** | [\`$(short_commit "${manager_commit}")\`](https://github.com/${manager_repo}/commit/${manager_commit}) |"
    fi
    if [[ -n "${sig_size}" ]]; then
      echo "| ✍️ **Signature size** | \`${sig_size}\` |"
    fi
    if [[ -n "${sig_hash}" ]]; then
      echo "| 🧾 **Signature hash** | \`${sig_hash}\` |"
    fi
    if [[ -n "${supported_line}" ]]; then
      echo "| 🤝 **Supported managers** | ${supported_line//,/, } |"
    fi
    if [[ "${manager_name}" == "kernelsu-next" && "$(get_info "${build_info}" enable_susfs)" == "true" ]]; then
      echo "| 📌 **Note** | Non-SUSFS builds use official \`KernelSU-Next/KernelSU-Next@dev\` · SUSFS builds use \`pershoot/dev-susfs\` |"
    fi
    if [[ -n "${app_url}" ]]; then
      echo "| 📦 **App** | [Manager releases](${app_url}) |"
    fi
    echo
    echo "</details>"
    echo
  done
  echo "---"
  echo

  echo "## 🛡️ SUSFS"
  echo
  if [[ "${enable_susfs_first}" == "true" ]]; then
    echo "| | |"
    echo "|:---|:---|"
    echo "| 🏷️ **Version** | \`${susfs_display}\` |"
    echo "| 🌿 **Kernel branch** | \`${susfs_branch}\` |"
    if [[ -n "${susfs_commit}" ]]; then
      echo "| 🔗 **Commit** | [\`$(short_commit "${susfs_commit}")\`](${susfs_url}) |"
    fi
    echo "| 📦 **Userspace module** | [sidex15/susfs4ksu-module](https://github.com/sidex15/susfs4ksu-module/releases) |"
    echo
    summary_susfs_module_note
  else
    echo "SUSFS is not enabled for this matrix."
  fi
  echo
  echo "---"
  echo

  echo "## 📦 Artifacts & checksums"
  echo
  echo "| Manager | File | Size | SHA-256 |"
  echo "|:---|:---|:---:|:---|"
  for artifact_dir in "${artifact_dirs[@]}"; do
    build_info="${artifact_dir}/build-info.txt"
    zip_env="${artifact_dir}/zip-name.env"
    [[ -f "${build_info}" && -f "${zip_env}" ]] || continue
    # shellcheck disable=SC1090
    source "${zip_env}"
    manager_name="$(get_info "${build_info}" manager)"
    display="$(manager_display "${manager_name}")"
    zip_path="${artifact_dir}/${zip_name}"
    if [[ -f "${zip_path}" ]]; then
      zip_size="$(du -h "${zip_path}" | awk '{print $1}')"
      zip_sha="$(sha256sum "${zip_path}" | awk '{print $1}')"
    else
      zip_size="missing"
      zip_sha="missing"
    fi
    echo "| ${display} | \`${zip_name}\` | ${zip_size} | \`${zip_sha}\` |"
  done
  echo
  echo "---"
  echo

  echo "## 📲 Installation"
  echo
  echo "<details>"
  echo "<summary><b>Prerequisites</b></summary>"
  echo
  echo "<br/>"
  echo
  echo "- 🔓 Unlocked bootloader"
  echo "- 📱 Poco F5 (\`marblein\`) or Redmi Note 12 Turbo (\`marble\`) only"
  echo "- 🧩 Kernel build that matches your **device + ROM**"
  echo "- 💾 Original \`boot.img\` from the same ROM/firmware stored **off-device**"
  echo "- 🧵 Free runners: avoid many parallel LOS+LLVM jobs; prefer \`lto=thin\`"
  for artifact_dir in "${artifact_dirs[@]}"; do
    build_info="${artifact_dir}/build-info.txt"
    manager_name="$(get_info "${build_info}" manager)"
    display="$(manager_display "${manager_name}")"
    app_url="$(manager_app_url "${manager_name}")"
    if [[ "${manager_name}" != "none" && -n "${app_url}" ]]; then
      echo "- 📦 [${display} manager app](${app_url}) for the ${display} ZIP"
    fi
  done
  if [[ "${enable_susfs_first}" == "true" ]]; then
    echo "- 🛡️ [KSU SUSFS module](https://github.com/sidex15/susfs4ksu-module/releases) matching \`${susfs_display}\`"
  fi
  echo
  echo "</details>"
  echo
  echo "<details>"
  echo "<summary><b>Flash steps</b> (Kernel Flasher recommended)</summary>"
  echo
  echo "<br/>"
  echo
  echo "1. Download the ZIP for **one** manager"
  echo "2. Verify **SHA-256** against the table above"
  echo "3. Flash to the **active slot** with [Kernel Flasher](https://github.com/fatalcoder524/KernelFlasher/releases)"
  echo "4. AnyKernel3 will verify codename (\`marble\` / \`marblein\`) and **auto-back up** boot to \`/sdcard/marble-kernel-backup/\`"
  echo "5. Reboot · install / open the matching manager app"
  if [[ "${enable_susfs_first}" == "true" ]]; then
    echo "6. Install the SUSFS userspace module, configure rules, reboot"
  fi
  echo
  echo "</details>"
  echo
  echo "> [!WARNING]"
  echo "> **Bootloop?** Flash the original \`boot.img\` from the same ROM/firmware back to the active slot (Kernel Flasher or fastboot). Keep that backup accessible **before** you flash."
  echo
  echo "---"
  echo

  echo "## 🙏 Credits"
  echo
  echo "| | |"
  echo "|:---|:---|"
  # Dynamic from build-info — never hardcode a maintainer name.
  credit_author="${kernel_source_author:-${kernel_source_id:-kernel}}"
  if [[ -n "${source_repo}" ]]; then
    echo "| 🧑‍💻 **Kernel source** | [${credit_author}](https://github.com/${source_repo}) (\`${source_repo}\`) |"
  else
    echo "| 🧑‍💻 **Kernel source** | ${credit_author} |"
  fi
  echo "| 📦 **AnyKernel3** | [osm0sis/AnyKernel3](https://github.com/osm0sis/AnyKernel3) |"
  seen_managers=""
  for artifact_dir in "${artifact_dirs[@]}"; do
    build_info="${artifact_dir}/build-info.txt"
    manager_name="$(get_info "${build_info}" manager)"
    [[ "${manager_name}" == "none" ]] && continue
    case " ${seen_managers} " in
      *" ${manager_name} "*) continue ;;
    esac
    seen_managers="${seen_managers} ${manager_name}"
    display="$(manager_display "${manager_name}")"
    m_repo="$(get_info "${build_info}" manager_repo)"
    if [[ -n "${m_repo}" ]]; then
      echo "| 🔑 **${display}** | [\`${m_repo}\`](https://github.com/${m_repo}) |"
    else
      echo "| 🔑 **${display}** | ${display} |"
    fi
  done
  if [[ "${enable_susfs_first}" == "true" ]]; then
    echo "| 🛡️ **SUSFS** | [simonpunk/susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu) |"
  fi
  echo
  echo "---"
  echo
  echo '<div align="center">'
  echo
  echo "**⚡ Built with GitHub Actions · for Marble**"
  echo
  echo "<br/>"
  echo
  echo "\`marble\` · \`marblein\`"
  echo
  echo '</div>'
} > "${MATRIX_SUMMARY}"

cat "${MATRIX_SUMMARY}"
