#!/bin/bash

set -e  # Exit on unhandled command failures

source "$(dirname -- "${BASH_SOURCE[0]}")/../support/setup/output.sh"

# Validate the saved profile before changing machine configuration.
source "$(dirname -- "${BASH_SOURCE[0]}")/../support/setup/machine-profile.sh"

sudo -v  # Request the administrator password up front

# Prepare clean state: creates the directories later steps write into and removes the five
# ~/.claude/ directories linked next, because `ln -sfn` cannot replace a real directory.
step "Prepare clean state"
source ~/.dotfiles/support/setup/clean-state.sh
success "Clean state prepared"

# Symlinks: needed before anything below can rely on ~/.aliases, ~/.zshrc etc. existing.
step "Creating symlinks"
source ~/.dotfiles/support/setup/symlink-dotfiles.sh
success "Symlinks created"

# Reapply the reviewed shared-skill links without reinstalling the skills.
source ~/.dotfiles/support/setup/codex/codex-skills.sh

# Create local config files if they don't exist
touch ~/.extra

# Herd onboarding: reconfigure does not install Herd, but it completes
# onboarding when an existing installation has not been initialized. The
# following steps need Herd's CLI binaries.
source ~/.dotfiles/support/setup/herd-onboarding.sh

# Install Xdebug configuration before any Herd project uses coverage or debug.
source ~/.dotfiles/support/setup/herd-debug-ini.sh

# tinkerbench (tinkerbench.test)
source ~/.dotfiles/support/setup/tinkerbench/tinkerbench.sh

# Configure some things: starts background services like mailpit and ollama.
step "Configure some things"
source ~/.dotfiles/support/setup/configure.sh
success "Some things configured"

# macOS defaults: run last because they quit the affected apps, Terminal among them.
step "Applying macOS defaults"
source ~/.dotfiles/support/setup/macos/osx-defaults.sh
