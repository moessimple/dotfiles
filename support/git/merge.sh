#!/usr/bin/env zsh

source "${0:A:h}/support/stash-guard.sh"

# Merge a branch into the current branch, stashing and restoring uncommitted changes
merge() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: merge <branch> [git merge options]"
        echo "  branch  Branch to merge into the current branch"
        echo "  Restores stashed changes after a successful merge; leaves them stashed on failure."
        return 0
    fi

    if (($# == 0)); then
        echo "No branch name given." >&2
        return 1
    fi

    local stashed exit_code
    _git_stash_guard || return
    stashed=$_git_stash_guard_active

    git merge "$@"
    exit_code=$?

    if ((exit_code != 0)); then
        ((stashed == 1)) && echo "Merge failed; your changes remain in the stash." >&2
        return "$exit_code"
    fi

    _git_stash_restore
}
