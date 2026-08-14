#!/usr/bin/env zsh

# Merge a branch into the current branch, stashing and restoring uncommitted changes
function gmerge() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: gmerge <branch> [git merge options]"
        echo "  branch  Branch to merge into the current branch"
        echo "  Restores stashed changes after a successful merge; leaves them stashed on failure."
        return 0
    fi

    [ $# -eq 0 ] && { echo "No branch name given."; return 1; }

    # `git stash push` on a clean tree creates no stash, so pop only if we stashed.
    local stashed=0 exit_code status_output
    status_output=$(git status --porcelain) || return
    if [ -n "$status_output" ]; then
        git stash push --include-untracked
        exit_code=$?
        [ "$exit_code" -eq 0 ] || return "$exit_code"
        stashed=1
    fi

    git merge "$@"
    exit_code=$?

    if [ "$exit_code" -ne 0 ]; then
        [ "$stashed" -eq 1 ] && echo "Merge failed; your changes remain in the stash." >&2
        return "$exit_code"
    fi

    if [ "$stashed" -eq 1 ]; then
        git stash pop
        return $?
    fi

    return 0
}
