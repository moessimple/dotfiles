#!/usr/bin/env zsh

# TODO: Match GitHub Desktop's branch-switch workflow by asking whether to bring
# local changes, leave them on the current branch, or cancel.
# Switch to a branch (creating it if needed), stashing and restoring uncommitted changes
function gswitch() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: gswitch <branch>"
        echo "  branch  Branch to switch to (created automatically if it does not exist)"
        echo "  Stashes uncommitted changes before switching and restores them afterwards."
        return 0
    fi

    [ $# -eq 0 ] && { echo "No branch name given."; return 1; }
    [ $# -ne 1 ] && { echo "Expected exactly one branch name."; return 1; }

    local requested_branch="$1" branch
    branch=$(git check-ref-format --branch "$requested_branch" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "Invalid branch name: $requested_branch" >&2
        return 1
    fi

    local stashed=0 exit_code status_output stash_before stash_after remote_branches
    status_output=$(git status --porcelain) || return
    if [ -n "$status_output" ]; then
        stash_before=$(git rev-parse -q --verify refs/stash 2>/dev/null)
        git stash push --include-untracked
        exit_code=$?
        [ "$exit_code" -eq 0 ] || return "$exit_code"

        stash_after=$(git rev-parse -q --verify refs/stash 2>/dev/null)
        if [ -z "$stash_after" ] || [ "$stash_after" = "$stash_before" ]; then
            echo "Could not stash local changes; branch was not switched." >&2
            return 1
        fi

        stashed=1
    fi

    if git show-ref --verify --quiet "refs/heads/$branch"; then
        git switch "$branch"
    else
        remote_branches=$(git for-each-ref --format='%(refname)' "refs/remotes/*/$branch") || return
        if [ -n "$remote_branches" ]; then
            git switch "$branch"
        else
            git switch -c "$branch"
        fi
    fi
    exit_code=$?

    if [ "$exit_code" -ne 0 ]; then
        [ "$stashed" -eq 1 ] && echo "Switch failed; your changes remain in the stash." >&2
        return "$exit_code"
    fi

    if [ "$stashed" -eq 1 ]; then
        git stash pop --index
        return $?
    fi

    return 0
}
