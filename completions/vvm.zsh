#!/bin/zsh
# Zsh tab-completion for vvm, vvm_push, and vvm_pull.
#
# Source this file from your shell configuration:
#   [ -f "/path/to/vvm/completions/vvm.zsh" ] && . "/path/to/vvm/completions/vvm.zsh"

# Ensure the completion system is initialized
if ! typeset -f compdef > /dev/null 2>&1; then
    autoload -Uz compinit && compinit
fi

# ---------------------------------------------------------------------------
# _fnListContainerPathsZsh: Query the running container for matching paths
# Arguments: sPartial - the partial path typed so far
# Returns: 0 if matches were added, 1 otherwise
# ---------------------------------------------------------------------------
_fnListContainerPathsZsh() {
    local sPartial="$1"
    if ! command -v docker > /dev/null 2>&1; then
        return 1
    fi
    if ! docker container inspect vvm > /dev/null 2>&1; then
        return 1
    fi
    local sOutput
    sOutput="$(docker exec vvm sh -c "ls -1dp /workspace/${sPartial}* 2>/dev/null" \
        | sed 's|^/workspace/||')"
    if [ -z "${sOutput}" ]; then
        return 1
    fi
    local daMatches=("${(@f)sOutput}")
    compadd -S '' -- "${daMatches[@]}"
    return 0
}

# ---------------------------------------------------------------------------
# _vvm: Complete flags for the vvm command
# ---------------------------------------------------------------------------
_vvm() {
    local sCurrent="${words[CURRENT]}"
    if [[ "${sCurrent}" == -* ]]; then
        compadd -- --help -h --status --build --claude --destroy --shell
        return
    fi
}
compdef _vvm vvm

# ---------------------------------------------------------------------------
# _vvm_pull: Complete container paths for vvm_pull sources
# ---------------------------------------------------------------------------
_vvm_pull() {
    local sCurrent="${words[CURRENT]}"
    if [[ "${sCurrent}" == -* ]]; then
        compadd -- -a -L -r -R --help -h
        return
    fi
    _fnListContainerPathsZsh "${sCurrent}" || _files
}
compdef _vvm_pull vvm_pull

# ---------------------------------------------------------------------------
# _vvm_push: Complete local files for sources, container paths for the
# destination (after at least one source has been typed)
# ---------------------------------------------------------------------------
_vvm_push() {
    local sCurrent="${words[CURRENT]}"
    if [[ "${sCurrent}" == -* ]]; then
        compadd -- -a -L -r -R --help -h
        return
    fi
    local iNonOptionCount=0
    local iIndex
    for (( iIndex=2; iIndex < CURRENT; iIndex++ )); do
        case "${words[iIndex]}" in
            -*) ;;
            *)  iNonOptionCount=$(( iNonOptionCount + 1 )) ;;
        esac
    done
    if [ "${iNonOptionCount}" -ge 1 ]; then
        _fnListContainerPathsZsh "${sCurrent}" || _files
    else
        _files
    fi
}
compdef _vvm_push vvm_push
