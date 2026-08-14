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

echo ""
# Entry point; nothing below runs until this is confirmed.
step "Install Dotfiles"
echo ""
warn "This will install/update your terminal setup"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    step "Cancelled"
    echo ""
    exit 0
fi

echo ""
sudo -v

# Prepare clean state: removes stale files/symlinks so the steps below start from a known
# state, not leftovers from a previous install.
step "Prepare clean state"
source ~/.dotfiles/support/setup/clean-state.sh
success "Clean state prepared"

# Oh My Zsh: guarded so a re-run doesn't reinstall over an existing checkout.
step "Installing Oh My Zsh"
if [ ! -d ~/.oh-my-zsh ]; then
    curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sh -s -- --unattended || warn "Oh My Zsh installation failed"
fi
success "Oh My Zsh installed"

# Homebrew: also wires it into .zprofile, so it's on PATH before anything below calls it.
step "Installing Homebrew"
if ! command -v brew &>/dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    grep -qF 'brew shellenv' ~/.zprofile 2>/dev/null || echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi
success "Homebrew installed"

# Symlinks: needed before anything below can rely on ~/.aliases, ~/.zshrc etc. existing.
step "Creating symlinks"
source ~/.dotfiles/support/setup/symlink-dotfiles.sh
success "Symlinks created"

# Brewfile: already-installed packages are skipped; any remaining bundle failure is
# downgraded to a warning so the installation can continue.
step "Installing packages from Brewfile"
brew bundle --file=~/.dotfiles/support/config/Brewfile || warn "Some packages failed (likely already installed)"
success "Brewfile processed"

# Global Composer packages
source ~/.dotfiles/support/setup/packages/composer-packages.sh

# Herd onboarding: Homebrew installs only the app bundle. The following steps
# need the CLI binaries created during Herd's one-time onboarding.
source ~/.dotfiles/support/setup/herd-onboarding.sh

# Install Xdebug configuration before any Herd project uses coverage or debug.
source ~/.dotfiles/support/setup/herd-debug-ini.sh

# tinkerbench (tinkerbench.test)
source ~/.dotfiles/support/setup/tinkerbench/tinkerbench.sh

# Global npm packages
source ~/.dotfiles/support/setup/packages/npm-packages.sh

# Claude Code skills
source ~/.dotfiles/support/setup/claude/claude-skills.sh

# Claude Code plugins: adds each marketplace, each plugin from CLAUDE_PLUGINS and the
# declared MCP servers; commands that fail are reported as warnings by claude-plugins.sh.
step "Installing Claude Code plugins and MCP servers"
source ~/.dotfiles/support/setup/claude/claude-plugins.sh

# Configure some things: starts background services like mailpit.
step "Configure some things"
source ~/.dotfiles/support/setup/configure.sh
success "Some things configured"

# Create local config files if they don't exist
touch ~/.extra

# macOS defaults — run last because some settings reload the shell
step "Applying macOS defaults"
source ~/.dotfiles/support/setup/macos/osx-defaults.sh
success "macOS defaults applied"

echo ""
success "Installation complete!"
echo ""
step "Next steps:"
echo "  • extra    — opens ~/.extra; add your personal aliases, tokens, and machine-specific settings here"
echo ""
step "Install from App Store:"
echo "  These apps cannot be installed via Homebrew — install them manually:"
echo "  • Amphetamine  (keep your Mac awake)"
echo ""
echo "Optional:"
echo "  • Discover more agent skills: https://skills.sh"
echo ""
