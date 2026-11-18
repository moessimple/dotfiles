#!/bin/bash

set -e

source ~/.dotfiles/support/setup/output.sh
source ~/.dotfiles/support/setup/machine-profile.sh
source ~/.dotfiles/support/setup/services.sh
source ~/.dotfiles/support/setup/herd/herd-onboarding.sh
source ~/.dotfiles/support/setup/herd/herd-xdebug.sh
source ~/.dotfiles/support/setup/tinkerbench.sh
source ~/.dotfiles/support/setup/home-directories.sh
source ~/.dotfiles/support/setup/oh-my-zsh.sh
source ~/.dotfiles/support/setup/dotfile-links.sh
source ~/.dotfiles/support/setup/packages/homebrew-packages.sh
source ~/.dotfiles/support/setup/packages/composer-packages.sh
source ~/.dotfiles/support/setup/packages/npm-packages.sh
source ~/.dotfiles/support/setup/packages/python-packages.sh
source ~/.dotfiles/support/setup/packages/ollama-models.sh
source ~/.dotfiles/support/setup/claude/claude-skills.sh
source ~/.dotfiles/support/setup/claude/claude-plugins.sh
source ~/.dotfiles/support/setup/codex/codex-skills.sh

load_machine_profile

echo ""
step "Install Dotfiles"
echo ""
note "This will install/update your terminal setup"
echo ""
read -p "Continue? (y/n) " -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    step "Cancelled"
    echo ""
    exit 0
fi

email=""
if [[ -f "$HOME/.config/dotfiles/profile" ]]; then
    email=$(git config --file "$HOME/.gitconfig-local" --get user.email 2>/dev/null || true)
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
        email_default=$(git config --global --includes --get user.email 2>/dev/null || true)
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

echo ""
sudo -v

prepare_home_directories

install_oh_my_zsh

# Installer shells do not read home/.zprofile, so a new Homebrew installation needs shellenv here.
step "Installing Homebrew"
if ! command -v brew &>/dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi
# A failed download runs the installer with an empty script, and shellenv of a missing brew
# prints nothing; both exit 0, so only finding brew shows that the installation worked.
command -v brew &>/dev/null || error "Homebrew installation failed"
success "Homebrew installed"

link_dotfiles

install_homebrew_packages

install_composer_packages

# Herd onboarding: Homebrew installs only the app bundle. The following steps
# need the CLI binaries created during Herd's one-time onboarding.
wait_for_herd_onboarding

# Install Xdebug configuration before any Herd project uses coverage or debug.
install_herd_xdebug

set_up_tinkerbench

install_npm_packages

# Python packages: after the Brewfile, which installs python3 and the PDF tools they call.
install_python_packages

install_claude_skills

install_claude_plugins

link_codex_skills

start_services

# Ollama models: after services.sh, which starts the Ollama service the pulls talk to.
install_ollama_models

# macOS defaults: run last because they quit the affected apps, Terminal among them.
step "Applying macOS defaults"
~/.dotfiles/bin/macos-defaults.sh || warn "Could not apply every macOS default, see the output above"

step "Next steps:"
echo "  • extra: opens ~/.extra; add your personal aliases, tokens, and machine-specific settings here"
echo ""
echo "Optional:"
echo "  • Discover more agent skills: https://skills.sh"

finish "Installation complete!"
echo ""
