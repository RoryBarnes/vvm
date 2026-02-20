#!/bin/sh
# uninstall_vvm.sh - Remove VVM and its Docker resources.
#
# Removes the Docker image, volume, and container created by VVM,
# the symlink and PATH entries created by install_vvm.sh, and the
# .claude_enabled marker if present. Does not uninstall Docker,
# Colima, or the GitHub CLI.
#
# Usage:
#   sh uninstall_vvm.sh

set -e

# ---------------------------------------------------------------------------
fnPrintError() { echo "ERROR: $1" >&2; }

# ---------------------------------------------------------------------------
# fbConfirmAction: Prompt the user for yes/no confirmation
# Arguments: sPrompt
# Returns: 0 if confirmed, 1 otherwise
# ---------------------------------------------------------------------------
fbConfirmAction() {
    sPrompt="$1"
    printf "%s [y/N] " "${sPrompt}"
    read -r sAnswer
    case "${sAnswer}" in
        [Yy]) return 0 ;;
        *)    return 1 ;;
    esac
}

# ---------------------------------------------------------------------------
# fnStopContainer: Stop any running VVM container
# ---------------------------------------------------------------------------
fnStopContainer() {
    if command -v docker > /dev/null 2>&1 \
            && docker container inspect vvm > /dev/null 2>&1; then
        echo "[uninstall] Stopping VVM container..."
        docker stop vvm 2>/dev/null || true
    fi
}

# ---------------------------------------------------------------------------
# fnRemoveImage: Remove the VVM Docker image
# ---------------------------------------------------------------------------
fnRemoveImage() {
    if ! command -v docker > /dev/null 2>&1; then
        echo "[uninstall] Docker not found. Skipping image removal."
        return
    fi
    if docker image inspect vvm:latest > /dev/null 2>&1; then
        echo "[uninstall] Removing Docker image vvm:latest..."
        docker rmi vvm:latest 2>/dev/null || true
    else
        echo "[uninstall] Docker image vvm:latest not found."
    fi
}

# ---------------------------------------------------------------------------
# fnRemoveVolume: Remove the VVM workspace volume (requires confirmation)
# ---------------------------------------------------------------------------
fnRemoveVolume() {
    if ! command -v docker > /dev/null 2>&1; then
        return
    fi
    if ! docker volume inspect vvm-workspace > /dev/null 2>&1; then
        echo "[uninstall] Workspace volume not found."
        return
    fi
    echo ""
    echo "WARNING: The workspace volume contains all cloned repositories,"
    echo "local commits, and branch checkouts."
    if fbConfirmAction "Delete the vvm-workspace volume?"; then
        docker volume rm vvm-workspace 2>/dev/null || true
        echo "[uninstall] Workspace volume removed."
    else
        echo "[uninstall] Keeping workspace volume."
    fi
}

# ---------------------------------------------------------------------------
# fnRemoveSymlink: Remove the vvm symlink from system bin directories
# ---------------------------------------------------------------------------
fnRemoveSymlink() {
    for sPath in /opt/local/bin/vvm /usr/local/bin/vvm; do
        if [ -L "${sPath}" ]; then
            echo "[uninstall] Removing symlink ${sPath}..."
            sudo rm -f "${sPath}"
            return
        fi
    done

    if command -v brew > /dev/null 2>&1; then
        sBrewLink="$(brew --prefix)/bin/vvm"
        if [ -L "${sBrewLink}" ]; then
            echo "[uninstall] Removing symlink ${sBrewLink}..."
            sudo rm -f "${sBrewLink}"
            return
        fi
    fi

    echo "[uninstall] No vvm symlink found."
}

# ---------------------------------------------------------------------------
# fnRemovePathEntry: Remove VVM PATH lines from shell configuration files
# ---------------------------------------------------------------------------
fnRemovePathEntry() {
    for sFile in \
        "${HOME}/.zshrc" \
        "${HOME}/.bashrc" \
        "${HOME}/.bash_profile" \
        "${HOME}/.profile" \
        "${HOME}/.config/fish/config.fish"
    do
        if [ ! -f "${sFile}" ]; then
            continue
        fi
        if ! grep -q "Added by VVM installer" "${sFile}" 2>/dev/null; then
            continue
        fi
        sTempFile="${sFile}.vvm_uninstall_tmp"
        { grep -v "Added by VVM installer" "${sFile}" \
            | grep -v "/vvm/bin" \
            | grep -v "/vvm/completions/"; } > "${sTempFile}" || true
        mv "${sTempFile}" "${sFile}"
        echo "[uninstall] Removed VVM PATH entry from ${sFile}."
    done
}

# ---------------------------------------------------------------------------
# fnRemoveClaudeMarker: Remove the .claude_enabled marker file
# ---------------------------------------------------------------------------
fnRemoveClaudeMarker() {
    sMarkerDir="$1"
    if [ -f "${sMarkerDir}/.claude_enabled" ]; then
        rm -f "${sMarkerDir}/.claude_enabled"
        echo "[uninstall] Removed Claude Code marker."
    fi
}

# ===========================================================================
# Main — only runs when executed directly (not when sourced by tests)
# ===========================================================================
if [ -n "${VVM_TESTING:-}" ]; then
    # shellcheck disable=SC2317
    return 0 2>/dev/null || true
fi

echo "=========================================="
echo "  VVM Uninstaller"
echo "=========================================="
echo ""
echo "This will remove:"
echo "  - The VVM Docker image"
echo "  - The VVM workspace volume (with confirmation)"
echo "  - The vvm symlink"
echo "  - VVM PATH entries from shell configuration"
echo ""
echo "This will NOT remove Docker, Colima, gh, or the VVM repository."
echo ""

if ! fbConfirmAction "Proceed with uninstall?"; then
    echo "[uninstall] Cancelled."
    exit 0
fi

echo ""
fnStopContainer
fnRemoveImage
fnRemoveVolume
fnRemoveSymlink
fnRemovePathEntry
sRepoDir="$(cd "$(dirname "$0")" && pwd)"
fnRemoveClaudeMarker "${sRepoDir}"

echo ""
echo "[uninstall] VVM has been uninstalled."
echo "[uninstall] To remove the VVM repository, delete this directory:"
echo "  rm -rf ${sRepoDir}"
