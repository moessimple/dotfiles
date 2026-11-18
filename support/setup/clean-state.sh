#!/bin/bash

# Creates the directories later steps write into and the machine-specific ~/.extra that .zshrc
# sources, and removes the five ~/.claude/ directories symlink_dotfiles_apply links next.
clean_state_apply() {
    step "Prepare clean state"
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
    success "Clean state prepared"
}
