#!/bin/bash

set -e

source ~/.dotfiles/support/setup/output.sh
source ~/.dotfiles/support/setup/machine-profile.sh
source ~/.dotfiles/support/setup/dotfiles-checkout.sh
source ~/.dotfiles/support/setup/packages/homebrew-packages.sh
source ~/.dotfiles/support/setup/packages/composer-packages.sh
source ~/.dotfiles/support/setup/packages/npm-packages.sh
source ~/.dotfiles/support/setup/packages/python-packages.sh
source ~/.dotfiles/support/setup/packages/ollama-models.sh
source ~/.dotfiles/support/setup/claude/claude-skills.sh
source ~/.dotfiles/support/setup/claude/claude-plugins.sh
source ~/.dotfiles/support/setup/claude/update-cooldown.sh

# Validate the saved profile before installing or removing packages.
load_machine_profile

# === Dotfiles repository ===
if [[ -z "${DOTFILES_UPDATE_PULLED:-}" ]]; then
    echo ""
    step "Updating dotfiles"
    echo ""

    pull_dotfiles

    # The pull replaces this file, but Bash keeps reading the copy it opened while sourcing the
    # pulled setup files, so a renamed function would abort the run. The pulled version takes over
    # instead, and the variable keeps it from pulling again.
    DOTFILES_UPDATE_PULLED=1 exec ~/.dotfiles/bin/update.sh
fi

# === Packages ===
update_homebrew_packages

install_composer_packages
update_composer_packages
clean_up_composer_packages

install_npm_packages
update_npm_packages
clean_up_npm_packages

install_python_packages
update_python_packages
clean_up_python_packages

# === Claude Code ===
install_claude_skills
update_claude_skills
clean_up_claude_skills

install_claude_plugins
update_claude_plugins
clean_up_claude_plugins

raise_npm_pins

# === Ollama models ===
install_ollama_models
clean_up_ollama_models

# === Configuration ===
step "Applying dotfiles configuration"
~/.dotfiles/bin/reconfigure.sh || warn "Could not apply the dotfiles configuration, see the output above"

finish "Update complete!"
echo ""
note "Restart your terminal or run: exec zsh"
echo ""
