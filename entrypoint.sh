#!/bin/bash

WORKSPACE="${WORKSPACE:-/workspace}"
REPOS_CONF="${REPOS_CONF:-/etc/vvm/repos.conf}"
VPLANET_BINARY="${WORKSPACE}/vplanet/bin/vplanet"

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
    local sToken=""

    if [ -f "${sTokenFile}" ]; then
        sToken=$(cat "${sTokenFile}")
    elif command -v gh > /dev/null 2>&1; then
        sToken=$(gh auth token 2>/dev/null || true)
    fi

    if [ -n "${sToken}" ]; then
        echo "[vvm] GitHub credentials detected."
        git config --system url."https://${sToken}@github.com/".insteadOf \
            "git@github.com:"
        git config --system --add url."https://${sToken}@github.com/".insteadOf \
            "https://github.com/"
    else
        echo "[vvm] No GitHub credentials found. Public repos only."
        echo "[vvm]   To access private repos, run on host: gh auth login"
        git config --system url."https://github.com/".insteadOf \
            "git@github.com:"
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
        if ! git clone --branch "${sBranch}" "${sUrl}" "${sRepoPath}" 2>&1; then
            echo "[vvm]   Clone failed for ${sName} (may require authentication)."
            return 0
        fi
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
    local sRepoPath=""

    if [ -d "${WORKSPACE}/vplanet-private/src" ]; then
        sRepoPath="${WORKSPACE}/vplanet-private"
        echo "[vvm] Building vplanet from vplanet-private..."
    elif [ -d "${WORKSPACE}/vplanet/src" ]; then
        sRepoPath="${WORKSPACE}/vplanet"
        echo "[vvm] Building vplanet from public repository..."
    else
        echo "[vvm] WARNING: No vplanet source found. Skipping build."
        return 0
    fi

    cd "${sRepoPath}"
    if ! make opt; then
        echo "[vvm] WARNING: vplanet build failed. You can retry manually:"
        echo "[vvm]   cd ${sRepoPath} && make opt"
        cd "${WORKSPACE}"
        return 0
    fi
    cd "${WORKSPACE}"

    VPLANET_BINARY="${sRepoPath}/bin/vplanet"
    export PATH="${sRepoPath}/bin:${PATH}"

    if [ -x "${VPLANET_BINARY}" ]; then
        echo "[vvm] vplanet binary ready: ${VPLANET_BINARY}"
        "${VPLANET_BINARY}" -v 2>/dev/null || true
    else
        echo "[vvm] WARNING: vplanet binary not found after build."
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
        if [ -d "${WORKSPACE}/${REPO_NAMES[$i]}" ]; then
            fnInstallRepo "${REPO_NAMES[$i]}" "${REPO_METHODS[$i]}"
        fi
    done

    echo ""
    echo "[vvm] All packages installed."
}

# ---------------------------------------------------------------------------
# fnPersistGitConfig: Symlink .gitconfig to the workspace volume
# ---------------------------------------------------------------------------
fnPersistGitConfig() {
    local sVolumeConfig="${WORKSPACE}/.gitconfig"

    touch "${sVolumeConfig}"
    ln -sfn "${sVolumeConfig}" /home/vplanet/.gitconfig
}

# ---------------------------------------------------------------------------
# fnPersistClaudeConfig: Symlink Claude Code config to the workspace volume
# ---------------------------------------------------------------------------
fnPersistClaudeConfig() {
    mkdir -p "${WORKSPACE}/.claude"
    ln -sfn "${WORKSPACE}/.claude" /home/vplanet/.claude
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
    if command -v node > /dev/null 2>&1; then
        echo "  Node.js:   $(node --version 2>&1)"
    fi
    if command -v claude > /dev/null 2>&1; then
        echo "  Claude:    $(claude --version 2>&1)"
    fi
    echo "  Cores:     $(nproc)"
    echo "=========================================="
    echo ""
}

# ===========================================================================
# Main — only runs when executed directly (not when sourced by tests)
# ===========================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail
    fnPrintBanner
    fnPersistGitConfig
    if command -v claude > /dev/null 2>&1; then
        fnPersistClaudeConfig
    fi
    fnConfigureGit
    fnParseReposConf
    fnSyncAllRepos
    fnBuildVplanet
    fnInstallAllRepos
    fnPrintSummary

    chown -R vplanet:vplanet "${WORKSPACE}"
    exec gosu vplanet "$@"
fi
