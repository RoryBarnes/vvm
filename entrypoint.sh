#!/bin/bash
set -euo pipefail

WORKSPACE="${WORKSPACE:-/workspace}"
REPOS_CONF="${REPOS_CONF:-/etc/vvm/repos.conf}"
VPLANET_BINARY="${WORKSPACE}/vplanet-private/bin/vplanet"

# ---------------------------------------------------------------------------
# fnPrintBanner: Display startup header
# ---------------------------------------------------------------------------
fnPrintBanner() {
    echo "=========================================="
    echo "  VVM - Virtual VPLanet Machine"
    echo "=========================================="
    echo ""
}

# ---------------------------------------------------------------------------
# fnConfigureGit: Configure GitHub authentication via token
# ---------------------------------------------------------------------------
fnConfigureGit() {
    local sTokenFile="/run/secrets/gh_token"

    if [ -f "${sTokenFile}" ]; then
        local sToken
        sToken=$(cat "${sTokenFile}")
        echo "[vvm] GitHub credentials detected."
        git config --global url."https://${sToken}@github.com/".insteadOf \
            "git@github.com:"
    else
        echo "[vvm] WARNING: No GitHub credentials found."
        echo "[vvm]   Private repos may fail to clone."
        echo "[vvm]   On host, run: gh auth login"
    fi
}

# ---------------------------------------------------------------------------
# fnParseReposConf: Read repos.conf into parallel arrays
# ---------------------------------------------------------------------------
fnParseReposConf() {
    REPO_NAMES=()
    REPO_URLS=()
    REPO_BRANCHES=()
    REPO_METHODS=()

    while IFS='|' read -r sName sUrl sBranch sMethod; do
        [[ "${sName}" =~ ^#.*$ ]] && continue
        [[ -z "${sName}" ]] && continue
        REPO_NAMES+=("${sName}")
        REPO_URLS+=("${sUrl}")
        REPO_BRANCHES+=("${sBranch}")
        REPO_METHODS+=("${sMethod}")
    done < "${REPOS_CONF}"
}

# ---------------------------------------------------------------------------
# fnCloneOrPull: Clone a repo if absent, pull if present
# Arguments: sName sUrl sBranch
# ---------------------------------------------------------------------------
fnCloneOrPull() {
    local sName="$1"
    local sUrl="$2"
    local sBranch="$3"
    local sRepoPath="${WORKSPACE}/${sName}"

    if [ ! -d "${sRepoPath}/.git" ]; then
        echo "[vvm] Cloning ${sName} (branch: ${sBranch})..."
        git clone --branch "${sBranch}" "${sUrl}" "${sRepoPath}"
        cd "${sRepoPath}"
        git fetch --tags origin
        cd "${WORKSPACE}"
    else
        echo "[vvm] Updating ${sName}..."
        cd "${sRepoPath}"
        git fetch origin --tags
        local sCurrentBranch
        sCurrentBranch=$(git rev-parse --abbrev-ref HEAD)
        if [ "${sCurrentBranch}" = "${sBranch}" ]; then
            git pull --ff-only origin "${sBranch}" 2>/dev/null || \
                echo "[vvm]   Pull skipped for ${sName} (local changes or diverged)."
        else
            echo "[vvm]   ${sName} on branch '${sCurrentBranch}', not '${sBranch}'. Skipping pull."
        fi
        cd "${WORKSPACE}"
    fi
}

# ---------------------------------------------------------------------------
# fnSyncAllRepos: Clone or pull every repo in repos.conf
# ---------------------------------------------------------------------------
fnSyncAllRepos() {
    echo "[vvm] Syncing repositories..."
    echo ""

    local iCount=${#REPO_NAMES[@]}
    for (( i=0; i<iCount; i++ )); do
        fnCloneOrPull "${REPO_NAMES[$i]}" "${REPO_URLS[$i]}" "${REPO_BRANCHES[$i]}"
    done

    echo ""
    echo "[vvm] All repositories synced."
}

# ---------------------------------------------------------------------------
# fnBuildVplanet: Compile the native C binary with optimizations
# ---------------------------------------------------------------------------
fnBuildVplanet() {
    local sRepoPath="${WORKSPACE}/vplanet-private"

    if [ ! -d "${sRepoPath}/src" ]; then
        echo "[vvm] ERROR: vplanet-private source not found."
        return 1
    fi

    echo "[vvm] Building vplanet C binary..."
    cd "${sRepoPath}"
    make opt
    cd "${WORKSPACE}"

    if [ -x "${VPLANET_BINARY}" ]; then
        echo "[vvm] vplanet binary ready: ${VPLANET_BINARY}"
        "${VPLANET_BINARY}" -v 2>/dev/null || true
    else
        echo "[vvm] ERROR: vplanet binary not found after build."
        return 1
    fi
}

# ---------------------------------------------------------------------------
# fnInstallRepo: Install a single repo per its install method
# Arguments: sName sMethod
# ---------------------------------------------------------------------------
fnInstallRepo() {
    local sName="$1"
    local sMethod="$2"
    local sRepoPath="${WORKSPACE}/${sName}"

    case "${sMethod}" in
        c_and_pip)
            echo "[vvm] Installing ${sName} Python package..."
            pip install -e "${sRepoPath}" --no-deps --no-build-isolation -q
            ;;
        pip_editable)
            echo "[vvm] Installing ${sName}..."
            pip install -e "${sRepoPath}" --no-build-isolation -q
            ;;
        pip_no_deps)
            echo "[vvm] Installing ${sName}..."
            pip install -e "${sRepoPath}" --no-deps --no-build-isolation -q
            ;;
        scripts_only)
            echo "[vvm] ${sName} available via PYTHONPATH and PATH."
            ;;
        reference)
            echo "[vvm] ${sName} cloned for reference (not installed)."
            ;;
        *)
            echo "[vvm] WARNING: Unknown install method '${sMethod}' for ${sName}."
            ;;
    esac
}

# ---------------------------------------------------------------------------
# fnInstallAllRepos: Install Python packages in dependency order
# ---------------------------------------------------------------------------
fnInstallAllRepos() {
    echo ""
    echo "[vvm] Installing Python packages..."

    local iCount=${#REPO_NAMES[@]}
    for (( i=0; i<iCount; i++ )); do
        fnInstallRepo "${REPO_NAMES[$i]}" "${REPO_METHODS[$i]}"
    done

    echo ""
    echo "[vvm] All packages installed."
}

# ---------------------------------------------------------------------------
# fnPrintSummary: Display environment summary
# ---------------------------------------------------------------------------
fnPrintSummary() {
    echo ""
    echo "=========================================="
    echo "  Environment Ready"
    echo "=========================================="
    echo "  Python:    $(python --version 2>&1)"
    echo "  GCC:       $(gcc --version | head -1)"
    echo "  vplanet:   ${VPLANET_BINARY}"
    echo "  Workspace: ${WORKSPACE}"
    echo "  Cores:     $(nproc)"
    echo "=========================================="
    echo ""
}

# ===========================================================================
# Main
# ===========================================================================

fnPrintBanner
fnConfigureGit
fnParseReposConf
fnSyncAllRepos
fnBuildVplanet
fnInstallAllRepos
fnPrintSummary

exec "$@"
