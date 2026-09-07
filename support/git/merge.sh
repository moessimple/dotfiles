#!/usr/bin/env zsh

source "${0:A:h}/support/stash-guard.sh"

# Merge a branch into the current branch, stashing and restoring uncommitted changes
function merge() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: merge <branch> [git merge options]"
        echo "  branch  Branch to merge into the current branch"
        echo "  Restores stashed changes after a successful merge; leaves them stashed on failure."
        return 0
    fi

    [ $# -eq 0 ] && { echo "No branch name given."; return 1; }

    local stashed exit_code
    _git_stash_guard || return
    stashed=$_git_stash_guard_active

    git merge "$@"
    exit_code=$?

    if [ "$exit_code" -ne 0 ]; then
        [ "$stashed" -eq 1 ] && echo "Merge failed; your changes remain in the stash." >&2
        return "$exit_code"
    fi

    _git_stash_restore
}
