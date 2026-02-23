#!/usr/bin/env bats
# Unit tests for uninstallVvm.sh functions.
# The VVM_TESTING guard lets us source the script without executing main.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    TEST_DIR="$(mktemp -d)"
    export VVM_TESTING=1
    source "${REPO_ROOT}/uninstallVvm.sh"
}

teardown() {
    rm -rf "${TEST_DIR}"
}

# ---------------------------------------------------------------------------
# fbConfirmAction
# ---------------------------------------------------------------------------

@test "fbConfirmAction: returns 0 for y" {
    echo y | fbConfirmAction "Continue?"

    [ $? -eq 0 ]
}

@test "fbConfirmAction: returns 1 for n" {
    echo n | fbConfirmAction "Continue?" && bFailed=false || bFailed=true

    [ "${bFailed}" = true ]
}

@test "fbConfirmAction: returns 1 for empty input" {
    echo "" | fbConfirmAction "Continue?" && bFailed=false || bFailed=true

    [ "${bFailed}" = true ]
}

# ---------------------------------------------------------------------------
# fnRemovePathEntry
# ---------------------------------------------------------------------------

@test "fnRemovePathEntry: removes VVM lines from rc file" {
    sTestRc="${TEST_DIR}/.zshrc"
    cat > "${sTestRc}" <<'EOF'
# Existing config
export EDITOR=vim

# Added by VVM installer
export PATH="/home/user/vvm/bin:$PATH"

alias ls='ls -la'
EOF

    HOME="${TEST_DIR}" fnRemovePathEntry

    run grep "VVM installer" "${sTestRc}"
    [ "$status" -eq 1 ]

    run grep "vvm/bin" "${sTestRc}"
    [ "$status" -eq 1 ]

    run grep "EDITOR=vim" "${sTestRc}"
    [ "$status" -eq 0 ]

    run grep "alias ls" "${sTestRc}"
    [ "$status" -eq 0 ]
}

@test "fnRemovePathEntry: preserves file when no VVM lines present" {
    sTestRc="${TEST_DIR}/.zshrc"
    echo "export EDITOR=vim" > "${sTestRc}"

    HOME="${TEST_DIR}" fnRemovePathEntry

    run grep "EDITOR=vim" "${sTestRc}"
    [ "$status" -eq 0 ]
}

@test "fnRemovePathEntry: handles fish shell config" {
    mkdir -p "${TEST_DIR}/.config/fish"
    sTestRc="${TEST_DIR}/.config/fish/config.fish"
    cat > "${sTestRc}" <<'EOF'
set -gx EDITOR vim

# Added by VVM installer
set -gx PATH /home/user/vvm/bin $PATH

alias ll='ls -la'
EOF

    HOME="${TEST_DIR}" fnRemovePathEntry

    run grep "VVM installer" "${sTestRc}"
    [ "$status" -eq 1 ]

    run grep "vvm/bin" "${sTestRc}"
    [ "$status" -eq 1 ]

    run grep "EDITOR vim" "${sTestRc}"
    [ "$status" -eq 0 ]
}

@test "fnRemovePathEntry: skips missing rc files" {
    HOME="${TEST_DIR}" run fnRemovePathEntry

    [ "$status" -eq 0 ]
}

@test "fnRemovePathEntry: handles multiple rc files" {
    sZshrc="${TEST_DIR}/.zshrc"
    sBashrc="${TEST_DIR}/.bashrc"

    cat > "${sZshrc}" <<'EOF'
# Added by VVM installer
export PATH="/home/user/vvm/bin:$PATH"
EOF

    cat > "${sBashrc}" <<'EOF'
# Added by VVM installer
export PATH="/home/user/vvm/bin:$PATH"
EOF

    HOME="${TEST_DIR}" fnRemovePathEntry

    run grep "VVM installer" "${sZshrc}"
    [ "$status" -eq 1 ]

    run grep "VVM installer" "${sBashrc}"
    [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# fnRemoveClaudeMarker
# ---------------------------------------------------------------------------

@test "fnRemoveClaudeMarker: removes existing marker" {
    touch "${TEST_DIR}/.claude_enabled"

    run fnRemoveClaudeMarker "${TEST_DIR}"

    [ "$status" -eq 0 ]
    [ ! -f "${TEST_DIR}/.claude_enabled" ]
    [[ "$output" =~ "Removed Claude Code marker" ]]
}

@test "fnRemoveClaudeMarker: no error when marker missing" {
    run fnRemoveClaudeMarker "${TEST_DIR}"

    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# fnRemoveSymlink
# ---------------------------------------------------------------------------

@test "fnRemoveSymlink: reports no symlink found when none exist" {
    # Skip if a real VVM symlink is installed on this machine
    for sPath in /opt/local/bin/vvm /usr/local/bin/vvm; do
        if [ -L "${sPath}" ]; then
            skip "real vvm symlink exists at ${sPath}"
        fi
    done

    run fnRemoveSymlink

    [ "$status" -eq 0 ]
    [[ "$output" =~ "No vvm symlink found" ]]
}

# ---------------------------------------------------------------------------
# Source guard
# ---------------------------------------------------------------------------

@test "source guard prevents main from executing" {
    run bash -c 'export VVM_TESTING=1; . "'"${REPO_ROOT}"'/uninstallVvm.sh"; echo sourced_ok'

    [ "$status" -eq 0 ]
    [[ "$output" =~ "sourced_ok" ]]
    [[ ! "$output" =~ "VVM Uninstaller" ]]
}
