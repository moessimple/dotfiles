#!/bin/bash

mkdir -p ~/Screenshots
mkdir -p ~/Temp
mkdir -p ~/Code
mkdir -p ~/.config/ghostty
mkdir -p ~/.claude

# ln -sf replaces an existing file or symlink on its own; a real (non-symlink) directory is the
# one case it can't replace, so these five are cleared first if they pre-date this repo.
rm -rf ~/.claude/agents
rm -rf ~/.claude/commands
rm -rf ~/.claude/hooks
rm -rf ~/.claude/rules
rm -rf ~/.claude/skills
