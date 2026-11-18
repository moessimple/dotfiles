#!/bin/bash

install_oh_my_zsh() {
    step "Installing Oh My Zsh"
    # The directory check also catches a failed download, which leaves sh with empty input and
    # a zero exit status.
    if [[ -d ~/.oh-my-zsh ]]; then
        success "Oh My Zsh already installed"
    elif curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sh -s -- --unattended \
        && [[ -d ~/.oh-my-zsh ]]; then
        success "Oh My Zsh installed"
    else
        warn "Oh My Zsh installation failed"
    fi
}
