#!/bin/bash

# Pulls only into a clean main checkout: the Claude CLI and skill updates in bin/update.sh write to
# configuration tracked in this repository, and pulling over local changes can leave conflicted
# settings active. `git pull --autostash` can do exactly that and still exit 0.
pull_dotfiles() {
    local current_branch
    step "Pulling latest changes"
    if ! git -C ~/.dotfiles rev-parse --git-dir &>/dev/null; then
        error "~/.dotfiles is not a Git repository."
    fi

    if ! current_branch="$(git -C ~/.dotfiles symbolic-ref --quiet --short HEAD)"; then
        error "~/.dotfiles is in detached HEAD state. Check out main, then run update again."
    fi

    if [[ "$current_branch" != "main" ]]; then
        error "~/.dotfiles is on '$current_branch'. Check out main, then run update again."
    fi

    if [[ -n "$(git -C ~/.dotfiles status --porcelain)" ]]; then
        echo ""
        git -C ~/.dotfiles status --short
        echo ""
        error "~/.dotfiles has uncommitted changes. Stash them (or commit and merge), then run update again."
    fi
    git -C ~/.dotfiles pull origin main
    success "Dotfiles updated"
}
