#!/bin/bash

# The packages are declared in support/config/Brewfile. Installing Homebrew itself stays in
# bin/install.sh, which needs it before anything here can run.

# Already-installed packages are skipped; any remaining bundle failure is downgraded to a
# warning so the installation can continue.
homebrew_packages_install() {
    step "Installing packages from Brewfile"
    if brew bundle --file=~/.dotfiles/support/config/Brewfile; then
        success "Brewfile processed"
    else
        warn "Some Brewfile packages failed to install, see the output above"
    fi
}

# update/upgrade first so bundle's own install and the cleanup below act on current formula
# versions. A package that cannot be updated is reported and the update goes on, as in
# homebrew_packages_install.
homebrew_packages_update() {
    step "Updating Homebrew packages"
    brew update || warn "Could not update Homebrew itself, see the output above"
    brew upgrade || warn "Could not upgrade every Homebrew package, see the output above"
    brew bundle --file=~/.dotfiles/support/config/Brewfile \
        || warn "Some Brewfile packages failed to install, see the output above"
    # Without --force this only prompts, and an unattended prompt does nothing.
    brew bundle cleanup --force --file=~/.dotfiles/support/config/Brewfile \
        || warn "Could not remove every undeclared Homebrew package, see the output above"
    # --prune=all: update, upgrade and bundle just downloaded every declared package they
    # needed, so the whole download cache is stale. The default 120-day window lets casks
    # like Docker.dmg pile up GBs between prunes.
    brew cleanup --prune=all || warn "Could not prune Homebrew's download cache"
    success "Homebrew packages processed"
}
