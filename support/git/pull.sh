#!/usr/bin/env zsh

source "${0:A:h}/support/stash-guard.sh"

# Pull the current branch from origin while preserving uncommitted changes
function pull() {
    local current_branch
    current_branch=$(git symbolic-ref --quiet --short HEAD) || {
        echo "Cannot pull while HEAD is detached." >&2
        return 1
    }

    local stashed exit_code
    _git_stash_guard || return
    stashed=$_git_stash_guard_active

    git pull origin "$current_branch" "$@"
    exit_code=$?

    if [ "$exit_code" -ne 0 ]; then
        [ "$stashed" -eq 1 ] && echo "Pull failed; your changes remain in the stash." >&2
        return "$exit_code"
    fi

    _git_stash_restore
}
