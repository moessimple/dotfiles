#!/bin/bash

set -e # Exit on unhandled command failures

source "$(dirname -- "${BASH_SOURCE[0]}")/../support/setup/output.sh"

# Validate the saved profile before changing machine configuration.
source "$(dirname -- "${BASH_SOURCE[0]}")/../support/setup/machine-profile.sh"
machine_profile_load

source ~/.dotfiles/support/setup/services.sh
source ~/.dotfiles/support/setup/herd-onboarding.sh
source ~/.dotfiles/support/setup/herd-debug-ini.sh
source ~/.dotfiles/support/setup/tinkerbench/tinkerbench.sh
source ~/.dotfiles/support/setup/clean-state.sh
source ~/.dotfiles/support/setup/symlink-dotfiles.sh
source ~/.dotfiles/support/setup/codex/codex-skills.sh

clean_state_apply

symlink_dotfiles_apply

# Reapply the reviewed shared-skill links without reinstalling the skills.
codex_skills_link

# Create local config files if they don't exist
touch ~/.extra

# Herd onboarding: reconfigure does not install Herd, but it completes
# onboarding when an existing installation has not been initialized. The
# following steps need Herd's CLI binaries.
herd_onboarding_wait

# Install Xdebug configuration before any Herd project uses coverage or debug.
herd_debug_ini_install

# tinkerbench (tinkerbench.test)
tinkerbench_setup

services_start

finish "Configuration applied"
