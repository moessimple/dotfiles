#!/bin/bash

set -e

source ~/.dotfiles/support/setup/output.sh
source ~/.dotfiles/support/setup/machine-profile.sh
source ~/.dotfiles/support/setup/services.sh
source ~/.dotfiles/support/setup/herd/herd-onboarding.sh
source ~/.dotfiles/support/setup/herd/herd-xdebug.sh
source ~/.dotfiles/support/setup/tinkerbench.sh
source ~/.dotfiles/support/setup/home-directories.sh
source ~/.dotfiles/support/setup/oh-my-zsh.sh
source ~/.dotfiles/support/setup/dotfile-links.sh
source ~/.dotfiles/support/setup/homebrew.sh
source ~/.dotfiles/support/setup/packages/homebrew-packages.sh
source ~/.dotfiles/support/setup/packages/composer-packages.sh
source ~/.dotfiles/support/setup/packages/npm-packages.sh
source ~/.dotfiles/support/setup/packages/python-packages.sh
source ~/.dotfiles/support/setup/packages/ollama-models.sh
source ~/.dotfiles/support/setup/claude/claude-skills.sh
source ~/.dotfiles/support/setup/claude/claude-plugins.sh
source ~/.dotfiles/support/setup/codex/codex-skills.sh

load_machine_profile

echo ""
step "Install Dotfiles"
echo ""
note "This will install/update your terminal setup"
echo ""
read -p "Continue? (y/n) " -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    step "Cancelled"
    echo ""
    exit 0
fi

set_up_machine_profile

echo ""
sudo -v

prepare_home_directories

install_oh_my_zsh

install_homebrew

link_dotfiles

install_homebrew_packages

install_composer_packages

# Herd onboarding: Homebrew installs only the app bundle. The following steps
# need the CLI binaries created during Herd's one-time onboarding.
wait_for_herd_onboarding

# Install Xdebug configuration before any Herd project uses coverage or debug.
install_herd_xdebug

set_up_tinkerbench

install_npm_packages

# Python packages: after the Brewfile, which installs python3 and the PDF tools they call.
install_python_packages

install_claude_skills

install_claude_plugins

link_codex_skills

start_services

# Ollama models: after services.sh, which starts the Ollama service the pulls talk to.
install_ollama_models

# macOS defaults: run last because they quit the affected apps, Terminal among them.
step "Applying macOS defaults"
~/.dotfiles/bin/macos-defaults.sh || warn "Could not apply every macOS default, see the output above"

step "Next steps:"
echo "  • extra: opens ~/.extra; add your personal aliases, tokens, and machine-specific settings here"
echo ""
echo "Optional:"
echo "  • Discover more agent skills: https://skills.sh"

finish "Installation complete!"
echo ""
