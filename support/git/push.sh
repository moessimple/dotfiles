#!/usr/bin/env zsh

# Push the current branch to origin and set its upstream
function gpush() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: gpush [git push options]"
        echo "  Pushes the current branch to origin, setting it as upstream."
        return 0
    fi

    git push -u origin $(git current-branch) "$@"
}
