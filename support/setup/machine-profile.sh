#!/bin/bash

# Existing machines remain private until install explicitly saves a profile.
DOTFILES_PROFILE=private
if [ -f "$HOME/.config/dotfiles/profile" ]; then
    DOTFILES_PROFILE=$(cat "$HOME/.config/dotfiles/profile")
    case "$DOTFILES_PROFILE" in
        private|work) ;;
        *) error "Invalid machine profile in ~/.config/dotfiles/profile. Expected private or work." ;;
    esac
fi
