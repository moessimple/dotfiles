#!/bin/bash

load_machine_profile() {
    # Existing machines remain private until install explicitly saves a profile.
    DOTFILES_PROFILE=private
    if [[ -f "$HOME/.config/dotfiles/profile" ]]; then
        DOTFILES_PROFILE="$(cat "$HOME/.config/dotfiles/profile")"
        case "$DOTFILES_PROFILE" in
            private | work) ;;
            *) error "Invalid machine profile in ~/.config/dotfiles/profile. Expected private or work." ;;
        esac
    fi
}

# Asks for the profile when none is saved and for the Git email when ~/.gitconfig-local has none.
# The profile is saved only after the email is written, so an aborted setup asks again next time.
set_up_machine_profile() {
    local email email_default choice
    email=""
    if [[ -f "$HOME/.config/dotfiles/profile" ]]; then
        email="$(git config --file "$HOME/.gitconfig-local" --get user.email 2>/dev/null || true)"
    else
        echo "What kind of machine is this?"
        echo "1) Private"
        echo "2) Work"
        while true; do
            read -r -p "Choose [1/2]: " choice || error "No machine profile selected."
            case "$choice" in
                1)
                    DOTFILES_PROFILE=private
                    break
                    ;;
                2)
                    DOTFILES_PROFILE=work
                    break
                    ;;
                *) echo "Please choose 1 or 2." ;;
            esac
        done
    fi

    if [[ -z "${email//[[:space:]]/}" ]]; then
        email_default=""
        if [[ "$DOTFILES_PROFILE" == "private" ]]; then
            email_default="$(git config --global --includes --get user.email 2>/dev/null || true)"
        fi
        while true; do
            read -r -p "Git email for this $DOTFILES_PROFILE machine${email_default:+ [$email_default]}: " email \
                || error "No Git email entered."
            email="${email:-$email_default}"
            if [[ -n "${email//[[:space:]]/}" ]]; then
                break
            fi
            echo "Please enter your Git email."
        done
        (
            umask 077
            git config --file "$HOME/.gitconfig-local" user.email "$email"
        ) \
            || error "Could not save the Git email in ~/.gitconfig-local."

        mkdir -p "$HOME/.config/dotfiles"
        printf '%s\n' "$DOTFILES_PROFILE" >"$HOME/.config/dotfiles/profile"
    fi
}
