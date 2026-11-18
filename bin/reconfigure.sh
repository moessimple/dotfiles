#!/bin/bash

set -e

source ~/.dotfiles/support/setup/output.sh
source ~/.dotfiles/support/setup/machine-profile.sh
source ~/.dotfiles/support/setup/home-directories.sh
source ~/.dotfiles/support/setup/dotfile-links.sh
source ~/.dotfiles/support/setup/codex/codex-skills.sh
source ~/.dotfiles/support/setup/herd/herd-onboarding.sh
source ~/.dotfiles/support/setup/herd/herd-xdebug.sh
source ~/.dotfiles/support/setup/tinkerbench.sh
source ~/.dotfiles/support/setup/services.sh

# Validate the saved profile before changing machine configuration.
load_machine_profile

# === Base system ===
prepare_home_directories
link_dotfiles

# === Claude Code and Codex ===
# Reapply the reviewed shared-skill links without reinstalling the skills.
link_codex_skills

# === Herd ===
# Reconfigure does not install Herd, but it completes onboarding when an existing
# installation has not been initialized. The following steps need Herd's CLI binaries.
wait_for_herd_onboarding
# Install Xdebug configuration before any Herd project uses coverage or debug.
install_herd_xdebug
set_up_tinkerbench

# === Services ===
start_services

finish "Configuration applied"
