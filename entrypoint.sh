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
# fsReadGitHubToken: Find and return a GitHub token from secrets or gh CLI
# ---------------------------------------------------------------------------
fsReadGitHubToken() {
    local sTokenFile="/run/secrets/gh_token"
    if [ -f "${sTokenFile}" ]; then
        cat "${sTokenFile}"
        return
    fi
    if command -v gh > /dev/null 2>&1; then
        gh auth token 2>/dev/null || true
    fi
}

# ---------------------------------------------------------------------------
# fnConfigureGit: Configure GitHub authentication via token
# ---------------------------------------------------------------------------
fnConfigureGit() {
    local sToken
    sToken=$(fsReadGitHubToken)
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
    saRepoNames=()
    saRepoUrls=()
    saRepoBranches=()
    saRepoMethods=()

    while IFS='|' read -r sName sUrl sBranch sMethod; do
        [[ "${sName}" =~ ^#.*$ ]] && continue
        [[ -z "${sName}" ]] && continue
        saRepoNames+=("${sName}")
        saRepoUrls+=("${sUrl}")
        saRepoBranches+=("${sBranch}")
        saRepoMethods+=("${sMethod}")
    done < "${REPOS_CONF}"
}

# ---------------------------------------------------------------------------
# fnCloneRepo: Clone a repository that does not yet exist locally
# Arguments: sName sUrl sBranch
# ---------------------------------------------------------------------------
fnCloneRepo() {
    local sName="$1"
    local sUrl="$2"
    local sBranch="$3"
    local sRepoPath="${WORKSPACE}/${sName}"

    echo "[vvm] Cloning ${sName} (branch: ${sBranch})..."
    if ! git clone --branch "${sBranch}" "${sUrl}" "${sRepoPath}" 2>&1; then
        echo "[vvm]   Clone failed for ${sName} (may require authentication)."
        return 0
    fi
    cd "${sRepoPath}"
    git fetch --tags origin
    cd "${WORKSPACE}"
}

# ---------------------------------------------------------------------------
# fnUpdateRepo: Pull latest changes for an existing repository
# Arguments: sName sBranch
# ---------------------------------------------------------------------------
fnUpdateRepo() {
    local sName="$1"
    local sBranch="$2"
    local sRepoPath="${WORKSPACE}/${sName}"

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
}

# ---------------------------------------------------------------------------
# fnCloneOrPull: Clone a repo if absent, pull if present
# Arguments: sName sUrl sBranch
# ---------------------------------------------------------------------------
fnCloneOrPull() {
    local sName="$1"
    local sUrl="$2"
    local sBranch="$3"

    if [ ! -d "${WORKSPACE}/${sName}/.git" ]; then
        fnCloneRepo "${sName}" "${sUrl}" "${sBranch}"
    else
        fnUpdateRepo "${sName}" "${sBranch}"
    fi
}

# ---------------------------------------------------------------------------
# fnSyncAllRepos: Clone or pull every repo in repos.conf
# ---------------------------------------------------------------------------
fnSyncAllRepos() {
    echo "[vvm] Syncing repositories..."
    echo ""

    local iCount=${#saRepoNames[@]}
    for (( i=0; i<iCount; i++ )); do
        fnCloneOrPull "${saRepoNames[$i]}" "${saRepoUrls[$i]}" "${saRepoBranches[$i]}"
    done

    echo ""
    echo "[vvm] All repositories synced."
}

# ---------------------------------------------------------------------------
# fsFindVplanetSource: Locate the vplanet source directory
# ---------------------------------------------------------------------------
fsFindVplanetSource() {
    if [ -d "${WORKSPACE}/vplanet-private/src" ]; then
        echo "${WORKSPACE}/vplanet-private"
    elif [ -d "${WORKSPACE}/vplanet/src" ]; then
        echo "${WORKSPACE}/vplanet"
    fi
}

# ---------------------------------------------------------------------------
# fnCompileVplanet: Run the optimized build and update PATH
# ---------------------------------------------------------------------------
fnCompileVplanet() {
    local sRepoPath="$1"
    cd "${sRepoPath}"
    if ! make opt; then
        echo "[vvm] WARNING: vplanet build failed. You can retry manually:"
        echo "[vvm]   cd ${sRepoPath} && make opt"
        cd "${WORKSPACE}"
        return 1
    fi
    cd "${WORKSPACE}"
    VPLANET_BINARY="${sRepoPath}/bin/vplanet"
    export PATH="${sRepoPath}/bin:${PATH}"
}

# ---------------------------------------------------------------------------
# fnBuildVplanet: Compile the native C binary with optimizations
# ---------------------------------------------------------------------------
fnBuildVplanet() {
    local sRepoPath
    sRepoPath=$(fsFindVplanetSource)
    if [ -z "${sRepoPath}" ]; then
        echo "[vvm] WARNING: No vplanet source found. Skipping build."
        return 0
    fi

    echo "[vvm] Building vplanet from $(basename "${sRepoPath}")..."
    if ! fnCompileVplanet "${sRepoPath}"; then
        return 0
    fi

    if [ -x "${VPLANET_BINARY}" ]; then
        echo "[vvm] vplanet binary ready: ${VPLANET_BINARY}"
        "${VPLANET_BINARY}" -v 2>/dev/null || true
    else
        echo "[vvm] WARNING: vplanet binary not found after build."
    fi
}

# ---------------------------------------------------------------------------
# fnPipInstall: Run pip install with the given flags
# Arguments: sRepoPath sName [pip flags...]
# ---------------------------------------------------------------------------
fnPipInstall() {
    local sRepoPath="$1"
    local sName="$2"
    shift 2
    echo "[vvm] Installing ${sName}..."
    pip install -e "${sRepoPath}" "$@" -q
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
        c_and_pip|pip_no_deps)
            fnPipInstall "${sRepoPath}" "${sName}" --no-deps --no-build-isolation ;;
        pip_editable)
            fnPipInstall "${sRepoPath}" "${sName}" --no-build-isolation ;;
        scripts_only)
            echo "[vvm] ${sName} available via PYTHONPATH and PATH." ;;
        reference)
            echo "[vvm] ${sName} cloned for reference (not installed)." ;;
        *)
            echo "[vvm] WARNING: Unknown install method '${sMethod}' for ${sName}." ;;
    esac
}

# ---------------------------------------------------------------------------
# fnInstallAllRepos: Install Python packages in dependency order
# ---------------------------------------------------------------------------
fnInstallAllRepos() {
    echo ""
    echo "[vvm] Installing Python packages..."

    local iCount=${#saRepoNames[@]}
    for (( i=0; i<iCount; i++ )); do
        if [ -d "${WORKSPACE}/${saRepoNames[$i]}" ]; then
            fnInstallRepo "${saRepoNames[$i]}" "${saRepoMethods[$i]}"
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
