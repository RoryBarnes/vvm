#!/usr/bin/env bats
# Unit tests for entrypoint.sh functions.
# The source guard in entrypoint.sh lets us source it without executing main.

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

    # Source entrypoint.sh — the guard prevents main from running
    source "${REPO_ROOT}/entrypoint.sh"
}

teardown() {
    rm -rf "${TEST_DIR}"
}

# ---------------------------------------------------------------------------
# fnParseReposConf tests
# ---------------------------------------------------------------------------

@test "fnParseReposConf: parses correct number of entries" {
    fnParseReposConf

    [ "${#REPO_NAMES[@]}" -eq 3 ]
}

@test "fnParseReposConf: skips comment lines" {
    fnParseReposConf

    for sName in "${REPO_NAMES[@]}"; do
        [[ ! "${sName}" =~ ^# ]]
    done
}

@test "fnParseReposConf: skips blank lines" {
    fnParseReposConf

    for sName in "${REPO_NAMES[@]}"; do
        [ -n "${sName}" ]
    done
}

@test "fnParseReposConf: captures repo names correctly" {
    fnParseReposConf

    [ "${REPO_NAMES[0]}" = "repo-one" ]
    [ "${REPO_NAMES[1]}" = "repo-two" ]
    [ "${REPO_NAMES[2]}" = "repo-three" ]
}

@test "fnParseReposConf: captures URLs correctly" {
    fnParseReposConf

    [ "${REPO_URLS[0]}" = "git@github.com:org/repo-one.git" ]
    [ "${REPO_URLS[1]}" = "git@github.com:org/repo-two.git" ]
}

@test "fnParseReposConf: captures branches correctly" {
    fnParseReposConf

    [ "${REPO_BRANCHES[0]}" = "main" ]
    [ "${REPO_BRANCHES[1]}" = "v2.0" ]
    [ "${REPO_BRANCHES[2]}" = "develop" ]
}

@test "fnParseReposConf: captures install methods correctly" {
    fnParseReposConf

    [ "${REPO_METHODS[0]}" = "pip_no_deps" ]
    [ "${REPO_METHODS[1]}" = "c_and_pip" ]
    [ "${REPO_METHODS[2]}" = "scripts_only" ]
}

# ---------------------------------------------------------------------------
# fnPersistGitConfig tests
# ---------------------------------------------------------------------------

@test "fnPersistGitConfig: creates .gitconfig in workspace" {
    fnPersistGitConfig 2>/dev/null || true

    [ -f "${WORKSPACE}/.gitconfig" ]
}

@test "fnPersistGitConfig: creates symlink at /home/vplanet/.gitconfig" {
    if [ ! -d "/home/vplanet" ]; then
        skip "requires vplanet user (container only)"
    fi

    fnPersistGitConfig

    [ -L "/home/vplanet/.gitconfig" ]
    [ "$(readlink /home/vplanet/.gitconfig)" = "${WORKSPACE}/.gitconfig" ]
}

@test "fnPersistGitConfig: preserves existing config content" {
    echo "[user]" > "${WORKSPACE}/.gitconfig"
    echo "    name = Test User" >> "${WORKSPACE}/.gitconfig"

    fnPersistGitConfig 2>/dev/null || true

    grep -q "Test User" "${WORKSPACE}/.gitconfig"
}

# ---------------------------------------------------------------------------
# fnPersistClaudeConfig tests
# ---------------------------------------------------------------------------

@test "fnPersistClaudeConfig: creates .claude directory in workspace" {
    # ln to /root/.claude will fail without root; ignore that
    fnPersistClaudeConfig 2>/dev/null || true

    [ -d "${WORKSPACE}/.claude" ]
}

@test "fnPersistClaudeConfig: creates symlink at /home/vplanet/.claude" {
    if [ ! -d "/home/vplanet" ]; then
        skip "requires vplanet user (container only)"
    fi

    fnPersistClaudeConfig

    [ -L "/home/vplanet/.claude" ]
    [ "$(readlink /home/vplanet/.claude)" = "${WORKSPACE}/.claude" ]
}

# ---------------------------------------------------------------------------
# fnInstallRepo output tests
# ---------------------------------------------------------------------------

@test "fnInstallRepo: scripts_only prints expected message" {
    run fnInstallRepo "test-repo" "scripts_only"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "test-repo available via PYTHONPATH and PATH" ]]
}

@test "fnInstallRepo: reference prints expected message" {
    run fnInstallRepo "test-repo" "reference"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "cloned for reference" ]]
}

@test "fnInstallRepo: unknown method prints warning" {
    run fnInstallRepo "test-repo" "invalid_method"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "WARNING" ]]
}

# ---------------------------------------------------------------------------
# Empty repos.conf
# ---------------------------------------------------------------------------

@test "fnParseReposConf: handles empty repos.conf" {
    echo "" > "${TEST_DIR}/repos.conf"

    fnParseReposConf

    [ "${#REPO_NAMES[@]}" -eq 0 ]
}

@test "fnParseReposConf: handles comments-only repos.conf" {
    cat > "${TEST_DIR}/repos.conf" <<'CONF'
# This file has only comments
# and nothing else
CONF

    fnParseReposConf

    [ "${#REPO_NAMES[@]}" -eq 0 ]
}

# ---------------------------------------------------------------------------
# fnCloneOrPull failure tolerance
# ---------------------------------------------------------------------------

@test "fnCloneOrPull: returns 0 on clone failure" {
    run fnCloneOrPull "nonexistent" "https://github.com/invalid/repo.git" "main"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Clone failed" ]]
}

# ---------------------------------------------------------------------------
# fnConfigureGit HTTPS fallback
# ---------------------------------------------------------------------------

@test "fnConfigureGit: rewrites SSH to HTTPS without token" {
    if [ "$(id -u)" -ne 0 ]; then
        skip "requires root to write system git config"
    fi

    fnConfigureGit

    local sRewrite
    sRewrite=$(git config --system --get "url.https://github.com/.insteadOf" || true)
    [ "${sRewrite}" = "git@github.com:" ]
}

# ---------------------------------------------------------------------------
# fnInstallAllRepos skips missing repos
# ---------------------------------------------------------------------------

@test "fnInstallAllRepos: skips repos that were not cloned" {
    fnParseReposConf

    run fnInstallAllRepos

    [ "$status" -eq 0 ]
}
