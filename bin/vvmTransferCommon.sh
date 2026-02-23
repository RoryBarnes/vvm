#!/bin/sh
# vvmTransferCommon.sh - Shared functions for vvm_push and vvm_pull.
#
# Sourced by vvm_push and vvm_pull to avoid duplicating container
# verification, path resolution, and user confirmation logic.

VVM_CONTAINER="vvm"
VVM_WORKSPACE="/workspace"

# ---------------------------------------------------------------------------
fnPrintError() { echo "Error: $1" >&2; }

# ---------------------------------------------------------------------------
# fnCheckContainer: Verify the VVM container is running
# ---------------------------------------------------------------------------
fnCheckContainer() {
    if ! command -v docker > /dev/null 2>&1; then
        fnPrintError "docker not found on PATH."
        exit 1
    fi
    if ! docker container inspect "${VVM_CONTAINER}" > /dev/null 2>&1; then
        fnPrintError "VVM container is not running. Start it with: vvm"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# fsResolveContainerPath: Map a user-facing path to a workspace-absolute path
# Arguments: sRelativePath
# Prints: the resolved absolute path inside the container
# ---------------------------------------------------------------------------
fsResolveContainerPath() {
    case "$1" in
        /*) echo "${VVM_WORKSPACE}$1" ;;
        .)  echo "${VVM_WORKSPACE}" ;;
        *)  echo "${VVM_WORKSPACE}/$1" ;;
    esac
}

# ---------------------------------------------------------------------------
# fbConfirmRecursive: Prompt the user before copying a directory
# Arguments: sDisplayPath
# Returns: 0 if confirmed, 1 otherwise
# ---------------------------------------------------------------------------
fbConfirmRecursive() {
    printf "'%s' is a directory. Copy recursively? [y/N] " "$1"
    local sAnswer
    read -r sAnswer
    case "${sAnswer}" in
        [Yy]) return 0 ;;
        *)    return 1 ;;
    esac
}
