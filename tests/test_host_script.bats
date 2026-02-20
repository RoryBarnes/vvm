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

@test "check_isolation.sh has valid bash syntax" {
    run bash -n "${REPO_ROOT}/check_isolation.sh"

    [ "$status" -eq 0 ]
}

@test "bin/connect_vvm has valid shell syntax" {
    run sh -n "${REPO_ROOT}/bin/connect_vvm"

    [ "$status" -eq 0 ]
}

@test "install_vvm.sh has valid shell syntax" {
    run sh -n "${REPO_ROOT}/install_vvm.sh"

    [ "$status" -eq 0 ]
}

@test "uninstall_vvm.sh has valid shell syntax" {
    run sh -n "${REPO_ROOT}/uninstall_vvm.sh"

    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# install_vvm.sh argument parsing
# ---------------------------------------------------------------------------

@test "install_vvm.sh rejects unknown flags" {
    run sh "${REPO_ROOT}/install_vvm.sh" --bogus

    [ "$status" -eq 1 ]
}

@test "install_vvm.sh usage mentions -y flag" {
    run sh "${REPO_ROOT}/install_vvm.sh" --bogus

    [[ "$output" =~ "-y" ]]
}

# ---------------------------------------------------------------------------
# vvm_push and vvm_pull syntax
# ---------------------------------------------------------------------------

@test "bin/vvm_push has valid shell syntax" {
    run sh -n "${REPO_ROOT}/bin/vvm_push"

    [ "$status" -eq 0 ]
}

@test "bin/vvm_pull has valid shell syntax" {
    run sh -n "${REPO_ROOT}/bin/vvm_pull"

    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# vvm_push argument parsing
# ---------------------------------------------------------------------------

@test "vvm_push --help exits 0" {
    run sh "${REPO_ROOT}/bin/vvm_push" --help

    [ "$status" -eq 0 ]
}

@test "vvm_push --help prints usage line" {
    run sh "${REPO_ROOT}/bin/vvm_push" --help

    [[ "$output" =~ "Usage: vvm_push" ]]
}

@test "vvm_push -h is equivalent to --help" {
    run sh "${REPO_ROOT}/bin/vvm_push" -h

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage: vvm_push" ]]
}

@test "vvm_push with no arguments exits 1" {
    run sh "${REPO_ROOT}/bin/vvm_push"

    [ "$status" -eq 1 ]
    [[ "$output" =~ "source and destination are required" ]]
}

@test "vvm_push with one argument exits 1" {
    run sh "${REPO_ROOT}/bin/vvm_push" file.txt

    [ "$status" -eq 1 ]
    [[ "$output" =~ "source and destination are required" ]]
}

@test "vvm_push rejects unknown flags" {
    run sh "${REPO_ROOT}/bin/vvm_push" --bogus src dst

    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unknown option" ]]
}

@test "vvm_push help documents multiple sources" {
    run sh "${REPO_ROOT}/bin/vvm_push" --help

    [[ "$output" =~ "<host_source>..." ]]
}

# ---------------------------------------------------------------------------
# vvm_pull argument parsing
# ---------------------------------------------------------------------------

@test "vvm_pull --help exits 0" {
    run sh "${REPO_ROOT}/bin/vvm_pull" --help

    [ "$status" -eq 0 ]
}

@test "vvm_pull --help prints usage line" {
    run sh "${REPO_ROOT}/bin/vvm_pull" --help

    [[ "$output" =~ "Usage: vvm_pull" ]]
}

@test "vvm_pull -h is equivalent to --help" {
    run sh "${REPO_ROOT}/bin/vvm_pull" -h

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage: vvm_pull" ]]
}

@test "vvm_pull with no arguments exits 1" {
    run sh "${REPO_ROOT}/bin/vvm_pull"

    [ "$status" -eq 1 ]
    [[ "$output" =~ "source and destination are required" ]]
}

@test "vvm_pull with one argument exits 1" {
    run sh "${REPO_ROOT}/bin/vvm_pull" file.txt

    [ "$status" -eq 1 ]
    [[ "$output" =~ "source and destination are required" ]]
}

@test "vvm_pull rejects unknown flags" {
    run sh "${REPO_ROOT}/bin/vvm_pull" --bogus src dst

    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unknown option" ]]
}

@test "vvm_pull help documents multiple sources" {
    run sh "${REPO_ROOT}/bin/vvm_pull" --help

    [[ "$output" =~ "<container_source>..." ]]
}

# ---------------------------------------------------------------------------
# Completion script syntax
# ---------------------------------------------------------------------------

@test "completions/vvm.bash has valid bash syntax" {
    run bash -n "${REPO_ROOT}/completions/vvm.bash"

    [ "$status" -eq 0 ]
}

@test "completions/vvm.zsh has valid bash-compatible syntax" {
    run bash -n "${REPO_ROOT}/completions/vvm.zsh"

    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Completion helper: container path listing
# ---------------------------------------------------------------------------

@test "_fnListContainerPaths returns paths from mock docker" {
    docker() {
        case "$1" in
            container) return 0 ;;
            exec)
                printf "/workspace/vplanet/\n/workspace/vplot/\n"
                ;;
        esac
    }
    export -f docker

    source "${REPO_ROOT}/completions/vvm.bash"
    run _fnListContainerPaths "vpl"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "vplanet/" ]]
    [[ "$output" =~ "vplot/" ]]
}

@test "_fnListContainerPaths returns nothing when container not running" {
    docker() {
        case "$1" in
            container) return 1 ;;
        esac
    }
    export -f docker

    source "${REPO_ROOT}/completions/vvm.bash"
    run _fnListContainerPaths "vpl"

    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "_fnListContainerPaths returns nothing when docker not found" {
    PATH="/usr/bin:/bin"
    source "${REPO_ROOT}/completions/vvm.bash"
    run _fnListContainerPaths "vpl"

    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ---------------------------------------------------------------------------
# Dockerfile.claude
# ---------------------------------------------------------------------------

@test "Dockerfile.claude exists" {
    [ -f "${REPO_ROOT}/Dockerfile.claude" ]
}
