#!/bin/bash

install_homebrew() {
    step "Installing Homebrew"
    # Installer shells do not read home/.zprofile, so a new Homebrew installation needs shellenv here.
    if ! command -v brew &>/dev/null; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$("${HOMEBREW_PREFIX:-/opt/homebrew}/bin/brew" shellenv)"
    fi
    # A failed download runs the installer with an empty script, and shellenv of a missing brew
    # prints nothing; both exit 0, so only finding brew shows that the installation worked.
    command -v brew &>/dev/null || error "Homebrew installation failed"
    success "Homebrew installed"
}
