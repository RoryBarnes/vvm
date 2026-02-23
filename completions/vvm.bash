#!/bin/bash
# Bash tab-completion for vvm, vvm_push, and vvm_pull.
#
# Source this file from your shell configuration:
#   [ -f "/path/to/vvm/completions/vvm.bash" ] && . "/path/to/vvm/completions/vvm.bash"

# ---------------------------------------------------------------------------
# _fnListContainerPaths: Query the running container for matching paths
# Arguments: sPartial - the partial path typed so far
# Prints: matching paths relative to /workspace, one per line
# ---------------------------------------------------------------------------
_fnListContainerPaths() {
    local sPartial="$1"
    if ! command -v docker > /dev/null 2>&1; then
        return
    fi
    if ! docker container inspect vvm > /dev/null 2>&1; then
        return
    fi
    docker exec vvm sh -c "ls -1dp /workspace/${sPartial}* 2>/dev/null" \
        | sed 's|^/workspace/||'
}

# ---------------------------------------------------------------------------
# _fnCompleteVvm: Complete flags for the vvm command
# ---------------------------------------------------------------------------
_fnCompleteVvm() {
    local sCurrent="${COMP_WORDS[COMP_CWORD]}"
    if [[ "${sCurrent}" == -* ]]; then
        COMPREPLY=($(compgen -W "--help -h --status --build --claude --destroy --shell" -- "${sCurrent}"))
    fi
}
complete -F _fnCompleteVvm vvm

# ---------------------------------------------------------------------------
# _fnCompleteVvmPull: Complete container paths for vvm_pull sources
# ---------------------------------------------------------------------------
_fnCompleteVvmPull() {
    local sCurrent="${COMP_WORDS[COMP_CWORD]}"
    if [[ "${sCurrent}" == -* ]]; then
        COMPREPLY=($(compgen -W "-a -L -r -R --help -h" -- "${sCurrent}"))
        return
    fi
    local daMatches
    mapfile -t daMatches < <(_fnListContainerPaths "${sCurrent}")
    if [ ${#daMatches[@]} -gt 0 ]; then
        COMPREPLY=("${daMatches[@]}")
        compopt -o nospace
    fi
}
complete -o default -F _fnCompleteVvmPull vvm_pull

# ---------------------------------------------------------------------------
# _fnCompleteVvmPush: Complete local files for sources, container paths
# for the destination (after at least one source has been typed)
# ---------------------------------------------------------------------------
_fnCompleteVvmPush() {
    local sCurrent="${COMP_WORDS[COMP_CWORD]}"
    if [[ "${sCurrent}" == -* ]]; then
        COMPREPLY=($(compgen -W "-a -L -r -R --help -h" -- "${sCurrent}"))
        return
    fi
    local iNonOptionCount=0
    local iIndex
    for (( iIndex=1; iIndex < COMP_CWORD; iIndex++ )); do
        case "${COMP_WORDS[iIndex]}" in
            -*) ;;
            *)  iNonOptionCount=$(( iNonOptionCount + 1 )) ;;
        esac
    done
    if [ "${iNonOptionCount}" -ge 1 ]; then
        local daMatches
        mapfile -t daMatches < <(_fnListContainerPaths "${sCurrent}")
        if [ ${#daMatches[@]} -gt 0 ]; then
            COMPREPLY=("${daMatches[@]}")
            compopt -o nospace
        fi
    fi
}
complete -o default -F _fnCompleteVvmPush vvm_push
