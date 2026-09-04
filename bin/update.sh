#!/bin/bash

set -e  # Exit on unhandled command failures

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

step() { echo -e "${BLUE}➜${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; exit 1; }

echo ""
step "Updating dotfiles"
echo ""

# Update dotfiles repo
#
# Check before any other step because the Claude CLI and skill updates modify
# live configuration tracked in this repository. Pulling over those changes can
# conflict with incoming updates. `git pull --autostash` is not a safe
# substitute: it can advance the branch, fail to reapply the stash and still
# exit 0 while conflicted settings remain active.
step "Pulling latest changes"
if ! git -C ~/.dotfiles rev-parse --git-dir &>/dev/null; then
    error "~/.dotfiles is not a Git repository."
fi

if ! current_branch=$(git -C ~/.dotfiles symbolic-ref --quiet --short HEAD); then
    error "~/.dotfiles is in detached HEAD state. Check out main, then run update again."
fi

if [ "$current_branch" != "main" ]; then
    error "~/.dotfiles is on '$current_branch'. Check out main, then run update again."
fi

if [ -n "$(git -C ~/.dotfiles status --porcelain)" ]; then
    echo ""
    git -C ~/.dotfiles status --short
    echo ""
    error "~/.dotfiles has uncommitted changes. Stash them (or commit and merge), then run update again."
fi
git -C ~/.dotfiles pull origin main
success "Dotfiles updated"

# Homebrew: update/upgrade first so bundle's own install and the cleanup below act on
# current formula versions.
step "Updating Homebrew packages"
brew update
brew upgrade
brew bundle --file=~/.dotfiles/support/config/Brewfile
# --force because without it this only prompts, and a prompt it cannot show makes it a no-op.
# All five cleanups in this script remove undeclared things unattended, the declaration files
# are the only source of truth for what may be installed.
brew bundle cleanup --force --file=~/.dotfiles/support/config/Brewfile || true
# --prune=all: this runs weekly right after update/upgrade/bundle, so every declared
# package was just re-downloaded as needed and the entire download cache is stale.
# The default 120-day window lets casks like Docker.dmg accumulate GBs between prunes.
brew cleanup --prune=all
success "Homebrew packages updated"

# Install any global Composer packages newly added to the list, then update all
source ~/.dotfiles/support/setup/packages/composer-packages.sh
step "Updating global Composer packages"
composer global update
success "Composer packages updated"
composer_packages_cleanup

# Install any global npm packages newly added to the list, then update all
source ~/.dotfiles/support/setup/packages/npm-packages.sh
step "Updating global npm packages"
npm update -g --force
success "npm packages updated"
npm_packages_cleanup
# npm never evicts its own cache on its own; every `npm`/`npx` run only adds to it. `verify`
# garbage-collects unreferenced content and prunes it back toward `cache-max`, the npm
# counterpart to `brew cleanup` above.
npm cache verify

# Install any Claude Code skills newly added to the list, then update all
source ~/.dotfiles/support/setup/claude/claude-skills.sh
step "Updating Claude Code skills"
npx skills update -g
success "Claude Code skills updated"
claude_skills_cleanup

# Install any Claude Code plugins/MCP servers newly added to the list, then update all
source ~/.dotfiles/support/setup/claude/claude-plugins.sh
step "Updating Claude Code plugins"
for plugin in "${CLAUDE_PLUGINS[@]}"; do
    claude plugin update "$plugin" || true
done
success "Claude Code plugins updated"
claude_plugins_cleanup

echo ""
success "Update complete!"
echo ""
warn "Restart your terminal or run: exec zsh"
warn "This only updated package managers, run bin/reconfigure.sh too to apply symlink/setup script changes"
echo ""
