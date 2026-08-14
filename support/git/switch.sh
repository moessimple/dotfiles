#!/usr/bin/env zsh

# Switch to a branch (creating it if needed), stashing and restoring uncommitted changes
function gswitch() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: gswitch <branch>"
        echo "  branch  Branch to switch to (created automatically if it does not exist)"
        echo "  Stashes uncommitted changes before switching and restores them afterwards."
        return 0
    fi

    [ $# -eq 0 ] && { echo "No branch name given."; return 1; }

    # `git stash push` on a clean tree creates no stash, so pop only if we stashed.
    local stashed=0
    if [ -n "$(git status --porcelain)" ]; then
        git stash push --include-untracked
        stashed=1
    fi

    git switch "$@" 2>/dev/null || git switch -c "$@"
    local exit_code=$?

    [ "$stashed" -eq 1 ] && git stash pop

    return $exit_code
}
