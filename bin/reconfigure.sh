#!/bin/bash

set -e  # Exit on unhandled command failures

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

step() { echo ""; echo -e "${BLUE}➜${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; exit 1; }

sudo -v  # Request the administrator password up front

# Prepare clean state: removes stale files/symlinks so the steps below start from a known
# state, not leftovers from a previous install.
step "Prepare clean state"
source ~/.dotfiles/support/setup/clean-state.sh
success "Clean state prepared"

# Symlinks: needed before anything below can rely on ~/.aliases, ~/.zshrc etc. existing.
step "Creating symlinks"
source ~/.dotfiles/support/setup/symlink-dotfiles.sh
success "Symlinks created"

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

# Configure some things: starts background services like mailpit.
step "Configure some things"
source ~/.dotfiles/support/setup/configure.sh
success "Some things configured"

# macOS defaults — run last because some settings reload the shell
step "Applying macOS defaults"
source ~/.dotfiles/support/setup/macos/osx-defaults.sh
success "macOS defaults applied"
