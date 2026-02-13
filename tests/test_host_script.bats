#!/usr/bin/env bats
# Tests for the vvm host script that don't require Docker.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
VVM_SCRIPT="${REPO_ROOT}/vvm"

# ---------------------------------------------------------------------------
# Help output
# ---------------------------------------------------------------------------

@test "vvm --help exits 0" {
    run bash "${VVM_SCRIPT}" --help

    [ "$status" -eq 0 ]
}

@test "vvm --help prints usage line" {
    run bash "${VVM_SCRIPT}" --help

    [[ "$output" =~ "Usage: vvm" ]]
}

@test "vvm --help lists all subcommands" {
    run bash "${VVM_SCRIPT}" --help

    [[ "$output" =~ "--build" ]]
    [[ "$output" =~ "--status" ]]
    [[ "$output" =~ "--destroy" ]]
    [[ "$output" =~ "--shell" ]]
}

@test "vvm -h is equivalent to --help" {
    run bash "${VVM_SCRIPT}" -h

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage: vvm" ]]
}

# ---------------------------------------------------------------------------
# Script syntax
# ---------------------------------------------------------------------------

@test "vvm script has valid bash syntax" {
    run bash -n "${VVM_SCRIPT}"

    [ "$status" -eq 0 ]
}

@test "entrypoint.sh has valid bash syntax" {
    run bash -n "${REPO_ROOT}/entrypoint.sh"

    [ "$status" -eq 0 ]
}
