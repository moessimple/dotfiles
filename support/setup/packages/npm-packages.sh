#!/bin/bash

# Global npm packages
NPM_PACKAGES=(
    agent-browser
    intelephense
    typescript-language-server
    typescript
)
# npm, npx and corepack are managed as part of the Node toolchain rather than by
# this file, so npm_packages_cleanup keeps them even though they aren't declared
# in NPM_PACKAGES.
NPM_PACKAGES_KEEP=(
    npm
    corepack
    npx
)

# Installs each entry in NPM_PACKAGES; agent-browser's own setup runs right after.
step "Installing global npm packages"
for package in "${NPM_PACKAGES[@]}"; do
    npm install -g "$package" || warn "$package already installed or failed"
done
agent-browser install 2>/dev/null || warn "agent-browser setup skipped"
success "npm packages processed"

# Removes any globally installed npm package that isn't in NPM_PACKAGES or NPM_PACKAGES_KEEP.
# Same idea as `brew bundle cleanup --force` and claude_skills_cleanup in claude-skills.sh.
npm_packages_cleanup() {
    command -v npm &>/dev/null || return 0

    step "Checking for undeclared global npm packages"

    # pipefail, and the assignment kept out of `local`, so a failing npm or a missing jq
    # surfaces instead of looking like an empty list and reporting a green run over a broken one.
    local installed
    if ! installed=$(set -o pipefail; npm ls -g --depth=0 --json 2>/dev/null | jq -r '.dependencies // {} | keys[]'); then
        warn "Could not read global npm packages, skipping cleanup"
        return 0
    fi

    local name found_undeclared=0
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        if ! printf '%s\n' "${NPM_PACKAGES[@]}" "${NPM_PACKAGES_KEEP[@]}" | grep -qxF "$name"; then
            found_undeclared=1
            warn "Removing undeclared global npm package: $name (not in npm-packages.sh)"
            npm uninstall -g "$name" || warn "Could not remove $name, remove it manually"
        fi
    done <<< "$installed"

    # An `if`, not `&&`, which would return 1 after a removal and trip `set -e` in bin/update.sh
    if [ "$found_undeclared" -eq 0 ]; then
        success "No undeclared global npm packages found"
    fi
}
