#!/usr/bin/env zsh

# Sync local long-lived branches from upstream and push them to origin
function sync() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: sync"
        echo "  Fetches from upstream, resets develop/main/master/release to match upstream,"
        echo "  force-pushes them to origin, syncs tags, and runs prune."
        echo "  Requires an 'upstream' remote to be configured."
        return 0
    fi

    local current_branch current_commit
    current_branch=$(git symbolic-ref --quiet --short HEAD)
    if [ -z "$current_branch" ]; then
        current_commit=$(git rev-parse HEAD) || return
    fi
    local branches=("develop" "main" "master" "release")

    if ! git remote | grep -qxF upstream; then
        echo 'No upstream remote configured'
        return 1
    fi

    git fetch upstream --tags --jobs=10 || return

    # `git stash push` on a clean tree creates no stash, so pop only if we stashed.
    local stashed=0 status_output stash_exit
    status_output=$(git status --porcelain) || return
    if [ -n "$status_output" ]; then
        git stash push --include-untracked
        stash_exit=$?
        [ "$stash_exit" -eq 0 ] || return "$stash_exit"
        stashed=1
    fi

    local branch exit_code=0
    for branch in "${branches[@]}"; do
        if git show-ref --verify --quiet "refs/remotes/upstream/$branch"; then
            if git show-ref --verify --quiet "refs/heads/$branch"; then
                git switch "$branch"
            else
                git switch -c "$branch" "upstream/$branch"
            fi
            exit_code=$?
            [ "$exit_code" -eq 0 ] || break

            git reset --hard "upstream/$branch"
            exit_code=$?
            [ "$exit_code" -eq 0 ] || break

            git push origin "$branch" --force
            exit_code=$?
            [ "$exit_code" -eq 0 ] || break
        fi
    done

    if [ "$exit_code" -eq 0 ]; then
        git push origin --tags
        exit_code=$?
    fi

    local restore_exit
    if [ -n "$current_branch" ]; then
        git switch "$current_branch"
    else
        git switch --detach "$current_commit"
    fi
    restore_exit=$?

    if [ "$restore_exit" -ne 0 ]; then
        [ "$stashed" -eq 1 ] && echo "Could not restore the starting ref; your changes remain in the stash." >&2
        [ "$exit_code" -ne 0 ] && return "$exit_code"
        return "$restore_exit"
    fi

    local pop_exit=0
    if [ "$stashed" -eq 1 ]; then
        git stash pop
        pop_exit=$?
    fi

    [ "$exit_code" -ne 0 ] && return "$exit_code"
    [ "$pop_exit" -ne 0 ] && return "$pop_exit"

    prune
}
