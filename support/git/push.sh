#!/usr/bin/env zsh

# Push the current branch to origin and set its upstream
function push() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: push [git push options]"
        echo "  Pushes the current branch to origin, setting it as upstream."
        return 0
    fi

    local current_branch
    current_branch=$(git symbolic-ref --quiet --short HEAD) || {
        echo "Cannot push while HEAD is detached." >&2
        return 1
    }

    git push -u origin "$current_branch" "$@"
}
