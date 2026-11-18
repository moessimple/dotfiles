#!/bin/bash

# Global npm packages
NPM_PACKAGES=(
    agent-browser
    intelephense
    typescript-language-server
    typescript
)
# npm and corepack are managed as part of the Node toolchain rather than by this
# file, so npm_packages_cleanup keeps them even though they aren't declared in
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
agent_browser_prune_chrome() {
    local browsers="$HOME/.agent-browser/browsers"
    [[ -d "$browsers" ]] || return 0

    local newest
    newest=$(printf '%s\n' "$browsers"/chrome-* | sed 's#.*/chrome-##' | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1)

    local dir
    for dir in "$browsers"/chrome-*; do
        [[ -d "$dir" ]] || continue
        [[ "$dir" == "$browsers/chrome-$newest" ]] && continue
        rm -rf "$dir" || warn "Could not remove $dir"
    done
}

npm_packages_install() {
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
    agent_browser_prune_chrome
    success "npm packages processed"
}

npm_packages_update() {
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
# Same idea as `brew bundle cleanup --force` and claude_skills_cleanup in claude-skills.sh.
npm_packages_cleanup() {
    [[ -x "${HOMEBREW_PREFIX:-/opt/homebrew}/bin/npm" ]] || return 0

    step "Checking for undeclared global npm packages"

    # pipefail and a separate `local`, so a failing npm or a missing jq is reported instead
    # of reading as an empty list.
    local installed
    if ! installed=$(
        set -o pipefail
        global_npm ls -g --depth=0 --json 2>/dev/null | jq -r '.dependencies // {} | keys[]'
    ); then
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

    # An `if`, not `&&`, which would return 1 after a removal and trip `set -e` in bin/update.sh
    if ((found_undeclared == 0)); then
        success "No undeclared global npm packages found"
    fi
}

# Raises a pinned npm package to its newest stable release that is at least 3 days old, the same
# cooldown its npx call enforces. The raised pin is an uncommitted change in this repository and
# takes effect on the next run, which refuses a dirty worktree, so it is committed first.
raise_npm_pin() {
    local package="$1" file="$2" variable="$3"
    local current newest
    current=$(sed -n "s/^$variable=\"\(.*\)\"$/\1/p" "$file")
    # pipefail, so a failed npm lookup is reported instead of reading as "no newer release".
    # npm 12 wraps `npm view --json` output in an array, hence the leading .[0].
    if ! newest=$(
        set -o pipefail
        global_npm view "$package" time --json 2>/dev/null \
            | jq -r --arg current "$current" '
            def numbers: split(".") | map(tonumber);
            .[0]
            | to_entries
            | map(select(.key | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")))
            | map(select((.value | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) <= now - 3 * 86400))
            | map(select((.key | numbers) > ($current | numbers)))
            | max_by(.key | numbers) | .key // empty'
    ); then
        warn "Could not check $package for a newer release"
        return 0
    fi
    [[ -n "$newest" ]] || return 0

    if ! sed -i '' "s/^$variable=\"$current\"$/$variable=\"$newest\"/" "$file"; then
        warn "Could not raise $package from $current to $newest in ${file#"$HOME/"}"
        return 0
    fi
    note "Raised $package from $current to $newest in ${file#"$HOME/"}. Release notes: https://www.npmjs.com/package/$package/v/$newest. Commit the change before the next update."
}

npm_packages_raise_pins() {
    step "Checking pinned npm packages"
    raise_npm_pin chrome-devtools-mcp ~/.dotfiles/support/setup/claude/claude-plugins.sh CHROME_DEVTOOLS_MCP_VERSION
    raise_npm_pin skills ~/.dotfiles/support/setup/claude/claude-skills.sh SKILLS_CLI_VERSION
}
