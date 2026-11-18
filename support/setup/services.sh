#!/bin/bash

brew services start mailpit || warn "Could not start mailpit"

# Meilisearch refuses to start on a database written by an older version, so every
# `brew upgrade` that bumps it would leave the service crashing. The Homebrew service
# runs from the prefix's var directory, where Meilisearch reads ./config.toml on
# start; upgrade_db there migrates the local database in place. Rewritten on every run.
printf 'upgrade_db = true\n' >"${HOMEBREW_PREFIX:-/opt/homebrew}/var/config.toml" \
    || warn "Could not write the Meilisearch config.toml"
brew services start meilisearch || warn "Could not start meilisearch"

brew services start ollama || warn "Could not start ollama"
