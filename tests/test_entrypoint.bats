#!/usr/bin/env bats
# Unit tests for entrypoint.sh functions.
# These run without Docker by sourcing the script with mocks.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    # Create a temp directory for test fixtures
    TEST_DIR="$(mktemp -d)"

    # Create a test repos.conf
    cat > "${TEST_DIR}/repos.conf" <<'CONF'
# Comment line
repo-one|git@github.com:org/repo-one.git|main|pip_no_deps

repo-two|git@github.com:org/repo-two.git|v2.0|c_and_pip
repo-three|git@github.com:user/repo-three.git|develop|scripts_only
CONF

    # Set env vars that entrypoint.sh expects
    export WORKSPACE="${TEST_DIR}/workspace"
    export REPOS_CONF="${TEST_DIR}/repos.conf"
    mkdir -p "${WORKSPACE}"
}

teardown() {
    rm -rf "${TEST_DIR}"
}

# ---------------------------------------------------------------------------
# fnParseReposConf tests
# ---------------------------------------------------------------------------

@test "fnParseReposConf: parses correct number of entries" {
    source "${REPO_ROOT}/entrypoint.sh" --source-only 2>/dev/null || true

    # Source just the function definitions by extracting them
    eval "$(sed -n '/^fnParseReposConf/,/^}/p' "${REPO_ROOT}/entrypoint.sh")"

    fnParseReposConf

    [ "${#REPO_NAMES[@]}" -eq 3 ]
}

@test "fnParseReposConf: skips comment lines" {
    eval "$(sed -n '/^fnParseReposConf/,/^}/p' "${REPO_ROOT}/entrypoint.sh")"

    fnParseReposConf

    # No entry should be named "# Comment line"
    for sName in "${REPO_NAMES[@]}"; do
        [[ ! "${sName}" =~ ^# ]]
    done
}

@test "fnParseReposConf: skips blank lines" {
    eval "$(sed -n '/^fnParseReposConf/,/^}/p' "${REPO_ROOT}/entrypoint.sh")"

    fnParseReposConf

    # All names should be non-empty
    for sName in "${REPO_NAMES[@]}"; do
        [ -n "${sName}" ]
    done
}

@test "fnParseReposConf: captures repo names correctly" {
    eval "$(sed -n '/^fnParseReposConf/,/^}/p' "${REPO_ROOT}/entrypoint.sh")"

    fnParseReposConf

    [ "${REPO_NAMES[0]}" = "repo-one" ]
    [ "${REPO_NAMES[1]}" = "repo-two" ]
    [ "${REPO_NAMES[2]}" = "repo-three" ]
}

@test "fnParseReposConf: captures URLs correctly" {
    eval "$(sed -n '/^fnParseReposConf/,/^}/p' "${REPO_ROOT}/entrypoint.sh")"

    fnParseReposConf

    [ "${REPO_URLS[0]}" = "git@github.com:org/repo-one.git" ]
    [ "${REPO_URLS[1]}" = "git@github.com:org/repo-two.git" ]
}

@test "fnParseReposConf: captures branches correctly" {
    eval "$(sed -n '/^fnParseReposConf/,/^}/p' "${REPO_ROOT}/entrypoint.sh")"

    fnParseReposConf

    [ "${REPO_BRANCHES[0]}" = "main" ]
    [ "${REPO_BRANCHES[1]}" = "v2.0" ]
    [ "${REPO_BRANCHES[2]}" = "develop" ]
}

@test "fnParseReposConf: captures install methods correctly" {
    eval "$(sed -n '/^fnParseReposConf/,/^}/p' "${REPO_ROOT}/entrypoint.sh")"

    fnParseReposConf

    [ "${REPO_METHODS[0]}" = "pip_no_deps" ]
    [ "${REPO_METHODS[1]}" = "c_and_pip" ]
    [ "${REPO_METHODS[2]}" = "scripts_only" ]
}

# ---------------------------------------------------------------------------
# fnPersistClaudeConfig tests
# ---------------------------------------------------------------------------

@test "fnPersistClaudeConfig: creates .claude directory in workspace" {
    eval "$(sed -n '/^fnPersistClaudeConfig/,/^}/p' "${REPO_ROOT}/entrypoint.sh")"

    fnPersistClaudeConfig

    [ -d "${WORKSPACE}/.claude" ]
}

@test "fnPersistClaudeConfig: creates symlink at /root/.claude" {
    # Skip if not running as root (CI may not be root)
    if [ "$(id -u)" -ne 0 ]; then
        skip "requires root to write to /root"
    fi

    eval "$(sed -n '/^fnPersistClaudeConfig/,/^}/p' "${REPO_ROOT}/entrypoint.sh")"

    fnPersistClaudeConfig

    [ -L "/root/.claude" ]
    [ "$(readlink /root/.claude)" = "${WORKSPACE}/.claude" ]
}

# ---------------------------------------------------------------------------
# fnInstallRepo output tests
# ---------------------------------------------------------------------------

@test "fnInstallRepo: scripts_only prints expected message" {
    eval "$(sed -n '/^fnInstallRepo/,/^}/p' "${REPO_ROOT}/entrypoint.sh")"

    run fnInstallRepo "test-repo" "scripts_only"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "test-repo available via PYTHONPATH and PATH" ]]
}

@test "fnInstallRepo: reference prints expected message" {
    eval "$(sed -n '/^fnInstallRepo/,/^}/p' "${REPO_ROOT}/entrypoint.sh")"

    run fnInstallRepo "test-repo" "reference"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "cloned for reference" ]]
}

@test "fnInstallRepo: unknown method prints warning" {
    eval "$(sed -n '/^fnInstallRepo/,/^}/p' "${REPO_ROOT}/entrypoint.sh")"

    run fnInstallRepo "test-repo" "invalid_method"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "WARNING" ]]
}

# ---------------------------------------------------------------------------
# Empty repos.conf
# ---------------------------------------------------------------------------

@test "fnParseReposConf: handles empty repos.conf" {
    echo "" > "${TEST_DIR}/repos.conf"

    eval "$(sed -n '/^fnParseReposConf/,/^}/p' "${REPO_ROOT}/entrypoint.sh")"

    fnParseReposConf

    [ "${#REPO_NAMES[@]}" -eq 0 ]
}

@test "fnParseReposConf: handles comments-only repos.conf" {
    cat > "${TEST_DIR}/repos.conf" <<'CONF'
# This file has only comments
# and nothing else
CONF

    eval "$(sed -n '/^fnParseReposConf/,/^}/p' "${REPO_ROOT}/entrypoint.sh")"

    fnParseReposConf

    [ "${#REPO_NAMES[@]}" -eq 0 ]
}
