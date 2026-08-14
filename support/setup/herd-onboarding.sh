#!/bin/bash

# Homebrew installs only the Herd app bundle. Herd's one-time onboarding adds a
# default PHP version, privileged background services and its CLI binaries.
# Later setup needs those binaries, so a fresh machine waits here until
# onboarding finishes.
step "Waiting for Herd to finish onboarding"

export PATH="$HOME/Library/Application Support/Herd/bin:$PATH"

if ! command -v herd &>/dev/null; then
    open -a Herd
    warn "Herd needs a one-time setup: complete its onboarding in the app (it will ask for your admin password), this continues automatically once it's done"
    attempt=0
    until command -v herd &>/dev/null; do
        attempt=$((attempt + 1))
        if [ $((attempt % 12)) -eq 0 ]; then
            warn "Still waiting for Herd's onboarding to finish..."
        fi
        sleep 5
    done
fi

success "Herd is ready"
