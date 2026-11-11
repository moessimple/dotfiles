#!/bin/bash

set -e  # Exit on unhandled command failures

source "$(dirname -- "${BASH_SOURCE[0]}")/../support/setup/output.sh"

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

# Prepare clean state: creates the directories later steps write into and removes the five
# ~/.claude/ directories linked next, because `ln -sfn` cannot replace a real directory.
step "Prepare clean state"
source ~/.dotfiles/support/setup/clean-state.sh
success "Clean state prepared"

# Oh My Zsh: guarded so a re-run doesn't reinstall over an existing checkout.
step "Installing Oh My Zsh"
# The directory check also catches a failed download, which leaves sh with empty input and
# a zero exit status.
if [ -d ~/.oh-my-zsh ]; then
    success "Oh My Zsh already installed"
elif curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sh -s -- --unattended \
    && [ -d ~/.oh-my-zsh ]; then
    success "Oh My Zsh installed"
else
    warn "Oh My Zsh installation failed"
fi

# Homebrew: put on PATH for the rest of this run; later shells get it from the symlinked
# home/.zprofile.
step "Installing Homebrew"
if ! command -v brew &>/dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
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
if brew bundle --file=~/.dotfiles/support/config/Brewfile; then
    success "Brewfile processed"
else
    warn "Some Brewfile packages failed to install, see the output above"
fi

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

# Python packages: after the Brewfile, which installs python3 and the PDF tools they call.
source ~/.dotfiles/support/setup/packages/python-packages.sh

# Claude Code skills
source ~/.dotfiles/support/setup/claude/claude-skills.sh

# Claude Code plugins: adds each marketplace, each plugin from CLAUDE_PLUGINS and the
# declared MCP servers; commands that fail are reported as warnings by claude-plugins.sh.
source ~/.dotfiles/support/setup/claude/claude-plugins.sh

# Share reviewed standalone and plugin-provided skills with Codex after Claude installs them.
source ~/.dotfiles/support/setup/codex/codex-skills.sh

# Configure some things: starts background services like mailpit and ollama.
step "Configure some things"
source ~/.dotfiles/support/setup/configure.sh
success "Some things configured"

# Ollama models: after configure.sh, which starts the Ollama service the pulls talk to.
source ~/.dotfiles/support/setup/packages/ollama-models.sh

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
