#!/usr/bin/env zsh

# Pull the current branch from origin while preserving uncommitted changes
function gpull() {
    local current_branch
    current_branch=$(git symbolic-ref --quiet --short HEAD) || {
        echo "Cannot pull while HEAD is detached." >&2
        return 1
    }

    # `git stash push` on a clean tree creates no stash, so pop only if we stashed.
    local stashed=0 exit_code status_output
    status_output=$(git status --porcelain) || return
    if [ -n "$status_output" ]; then
        git stash push --include-untracked
        exit_code=$?
        [ "$exit_code" -eq 0 ] || return "$exit_code"
        stashed=1
    fi

    git pull origin "$current_branch" "$@"
    exit_code=$?

    if [ "$exit_code" -ne 0 ]; then
        [ "$stashed" -eq 1 ] && echo "Pull failed; your changes remain in the stash." >&2
        return "$exit_code"
    fi

    if [ "$stashed" -eq 1 ]; then
        git stash pop
        return $?
    fi

    return 0
}
