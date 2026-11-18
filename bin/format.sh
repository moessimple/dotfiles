#!/bin/bash

set -euo pipefail

repository=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
cd "$repository"

# Formats in place by default; --check only prints the diff and fails if anything is unformatted.
mode=-w
if [[ "${1:-}" == "--check" ]]; then
    mode=-d
fi

# Only tracked files, so untracked local scripts are never rewritten. shfmt does not detect the zsh
# dotfiles on its own, so they are listed by name. home/.zshrc and home/.zprofile stay out because
# Herd and Docker Desktop write their own blocks into them.
{
    git ls-files -z | xargs -0 shfmt -f=0
    printf '%s\0' home/.aliases home/.exports home/.functions home/.paths
} | xargs -0 shfmt --apply-ignore "$mode"
