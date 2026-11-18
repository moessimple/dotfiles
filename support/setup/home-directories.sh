#!/bin/bash

# Creates the directories later steps write into and the machine-specific ~/.extra that .zshrc
# sources, and removes the five ~/.claude/ directories link_dotfiles links next.
prepare_home_directories() {
    step "Preparing home directories"
    mkdir -p ~/Screenshots
    mkdir -p ~/Temp
    mkdir -p ~/Code
    mkdir -p ~/.config/ghostty
    mkdir -p ~/.config/git
    mkdir -p ~/.claude
    mkdir -p ~/.codex
    touch ~/.extra

    # ln -sf replaces an existing file or symlink on its own; a real (non-symlink) directory is the
    # one case it can't replace, so these five are cleared first if they pre-date this repo.
    rm -rf ~/.claude/agents
    rm -rf ~/.claude/commands
    rm -rf ~/.claude/hooks
    rm -rf ~/.claude/rules
    rm -rf ~/.claude/skills
    success "Home directories prepared"
}
