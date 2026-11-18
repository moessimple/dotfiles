#!/bin/bash

# Global npm packages
NPM_PACKAGES=(
    agent-browser
    intelephense
    typescript-language-server
    typescript
)
# npm and corepack are managed as part of the Node toolchain rather than by this
# file, so clean_up_npm_packages keeps them even though they aren't declared in
# NPM_PACKAGES.
NPM_PACKAGES_KEEP=(
    npm
    corepack
)

# Global packages go through Homebrew's npm, not the npm first on PATH: Herd's NVM gives each Node
# version its own global directory, so a Node switch by Herd would leave them behind and drop
# them from PATH. Homebrew's prefix stays put and is on PATH.
global_npm() {
    "${HOMEBREW_PREFIX:-/opt/homebrew}/bin/npm" "$@"
}

# `agent-browser install` downloads every new Chrome for Testing release (~360 MB each) next
# to the previous ones and never removes them. It always launches the newest version, so
# every older one is dead weight.
prune_agent_browser_chrome() {
    local browsers="$HOME/.agent-browser/browsers"
    [[ -d "$browsers" ]] || return 0

    local newest
    newest="$(printf '%s\n' "$browsers"/chrome-* | sed 's#.*/chrome-##' | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1)"

    local dir
    for dir in "$browsers"/chrome-*; do
        [[ -d "$dir" ]] || continue
        [[ "$dir" == "$browsers/chrome-$newest" ]] && continue
        rm -rf "$dir" || warn "Could not remove $dir"
    done
}

install_npm_packages() {
    step "Installing global npm packages"
    # A 3-day cooldown in the user config (~/.npmrc), the same window as Composer: install and update
    # skip releases younger than that, which keeps out hijacked releases that are found and pulled
    # within days. It applies to every npm on the machine, also Herd's; a project's own .npmrc takes
    # precedence. Set before the installs below so they wait too.
    global_npm config set min-release-age 3 || warn "Could not set the npm cooldown"
    local package
    for package in "${NPM_PACKAGES[@]}"; do
        global_npm install -g "$package" || warn "Could not install $package"
    done
    agent-browser install 2>/dev/null || warn "agent-browser setup skipped"
    prune_agent_browser_chrome
    success "npm packages processed"
}

update_npm_packages() {
    step "Updating global npm packages"
    if global_npm update -g --force; then
        success "npm packages updated"
    else
        warn "Could not update the global npm packages, see the output above"
    fi
    # npm never evicts its cache; every `npm`/`npx` run only adds to it. `verify` removes
    # unreferenced content and trims the cache toward `cache-max`.
    global_npm cache verify || warn "Could not verify the npm cache"
}

# Removes any globally installed npm package that isn't in NPM_PACKAGES or NPM_PACKAGES_KEEP.
# Same idea as `brew bundle cleanup --force` and clean_up_claude_skills in claude-skills.sh.
clean_up_npm_packages() {
    [[ -x "${HOMEBREW_PREFIX:-/opt/homebrew}/bin/npm" ]] || return 0

    step "Checking for undeclared global npm packages"

    local installed
    if ! installed="$(
        set -o pipefail
        global_npm ls -g --depth=0 --json 2>/dev/null | jq -r '.dependencies // {} | keys[]'
    )"; then
        warn "Could not read global npm packages, skipping cleanup"
        return 0
    fi

    local name found_undeclared=0
    while IFS= read -r name; do
        [[ -n "$name" ]] || continue
        printf '%s\n' "${NPM_PACKAGES[@]}" "${NPM_PACKAGES_KEEP[@]}" | grep -qxF "$name" && continue

        found_undeclared=1
        note "Removing undeclared global npm package: $name (not in npm-packages.sh)"
        global_npm uninstall -g "$name" || warn "Could not remove $name, remove it manually"
    done <<<"$installed"

    if ((found_undeclared == 0)); then
        success "No undeclared global npm packages found"
    fi
}
