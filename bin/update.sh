#!/bin/bash

set -e

source "$(dirname -- "${BASH_SOURCE[0]}")/../support/setup/output.sh"

# Validate the saved profile before installing or removing packages.
source "$(dirname -- "${BASH_SOURCE[0]}")/../support/setup/machine-profile.sh"
machine_profile_load

if [[ -z "${DOTFILES_UPDATE_PULLED:-}" ]]; then
    echo ""
    step "Updating dotfiles"
    echo ""

    # Runs first and refuses anything but a clean main checkout: the Claude CLI and skill
    # updates below write to configuration tracked in this repository, and pulling over local
    # changes can leave conflicted settings active. `git pull --autostash` can do exactly that
    # and still exit 0.
    step "Pulling latest changes"
    if ! git -C ~/.dotfiles rev-parse --git-dir &>/dev/null; then
        error "~/.dotfiles is not a Git repository."
    fi

    if ! current_branch=$(git -C ~/.dotfiles symbolic-ref --quiet --short HEAD); then
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

    # The pull replaces this file, but Bash keeps reading the copy it opened while sourcing the
    # pulled setup files, so a renamed function would abort the run. The pulled version takes over
    # instead, and the variable keeps it from pulling again.
    DOTFILES_UPDATE_PULLED=1 exec ~/.dotfiles/bin/update.sh
fi

source ~/.dotfiles/support/setup/packages/homebrew-packages.sh
source ~/.dotfiles/support/setup/packages/composer-packages.sh
source ~/.dotfiles/support/setup/packages/npm-packages.sh
source ~/.dotfiles/support/setup/packages/python-packages.sh
source ~/.dotfiles/support/setup/packages/ollama-models.sh
source ~/.dotfiles/support/setup/claude/claude-skills.sh
source ~/.dotfiles/support/setup/claude/claude-plugins.sh
source ~/.dotfiles/support/setup/claude/update-cooldown.sh

homebrew_packages_update

composer_packages_install
composer_packages_update
composer_packages_cleanup

npm_packages_install
npm_packages_update
npm_packages_cleanup

python_packages_install
python_packages_update
python_packages_cleanup

claude_skills_install
claude_skills_update
claude_skills_cleanup

claude_plugins_install
claude_plugins_update
claude_plugins_cleanup

ollama_models_install
ollama_models_cleanup

npm_packages_raise_pins

step "Applying dotfiles configuration"
~/.dotfiles/bin/reconfigure.sh || warn "Could not apply the dotfiles configuration, see the output above"

finish "Update complete!"
echo ""
note "Restart your terminal or run: exec zsh"
echo ""
