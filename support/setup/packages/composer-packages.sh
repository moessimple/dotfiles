#!/bin/bash

# Global Composer packages
COMPOSER_PACKAGES=(
    laravel/pint
    laravel/envoy
    laravel/lsp
    spatie/phpunit-watcher
    ion-bazan/composer-diff
    cpx/cpx
)

step "Installing global Composer packages"
# A 3-day cooldown in the machine-wide config, the same window as the npm tools and as the projects
# that set their own: update, require and remove skip releases younger than that, which keeps out
# hijacked releases that are found and pulled within days. A project's own policy.cooldown takes
# precedence. Set before the requires below so they wait too. `composer outdated` lists withheld
# releases; `--no-cooldown` takes one deliberately, which an urgent security fix needs.
composer config --global policy.cooldown.period "3 days" || warn "Could not set the Composer cooldown"
composer config --global policy.cooldown.audit report || warn "Could not set the Composer cooldown audit mode"
composer global config --no-plugins allow-plugins.ion-bazan/composer-diff true || warn "Could not allow-list the composer-diff plugin"
for package in "${COMPOSER_PACKAGES[@]}"; do
    composer global require --no-interaction "$package" || warn "$package already installed or failed"
done
success "Composer packages processed"

# Removes any globally required Composer package that isn't in COMPOSER_PACKAGES. Same idea
# as `brew bundle cleanup --force` and claude_skills_cleanup in claude-skills.sh: only direct
# requires are considered, so transitive dependencies are never touched.
composer_packages_cleanup() {
    command -v composer &>/dev/null || return 0

    step "Checking for undeclared global Composer packages"

    # pipefail and a separate `local`, so a failing composer or a missing jq is reported
    # instead of reading as an empty list.
    local installed
    if ! installed=$(set -o pipefail; composer global show -D --format=json 2>/dev/null | jq -r '.installed // [] | .[].name'); then
        warn "Could not read global Composer packages, skipping cleanup"
        return 0
    fi

    local name found_undeclared=0
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        if ! printf '%s\n' "${COMPOSER_PACKAGES[@]}" | grep -qxF "$name"; then
            found_undeclared=1
            warn "Removing undeclared Composer package: $name (not in composer-packages.sh)"
            composer global remove "$name" || warn "Could not remove $name, remove it manually"
        fi
    done <<< "$installed"

    # An `if`, not `&&`, which would return 1 after a removal and trip `set -e` in bin/update.sh
    if [ "$found_undeclared" -eq 0 ]; then
        success "No undeclared global Composer packages found"
    fi
}
