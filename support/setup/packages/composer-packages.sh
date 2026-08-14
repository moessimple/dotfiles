#!/bin/bash

# Global Composer packages
COMPOSER_PACKAGES=(
    laravel/pint
    laravel/envoy
    spatie/phpunit-watcher
    ion-bazan/composer-diff
    cpx/cpx
)

# Ensure each entry in COMPOSER_PACKAGES is globally required; failures are
# downgraded to warnings so the remaining packages can still be processed.
step "Installing global Composer packages"
composer global config --no-plugins allow-plugins.ion-bazan/composer-diff || warn "composer-diff already configured"
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

    # pipefail, and the assignment kept out of `local`, so a failing composer or a missing jq
    # surfaces instead of looking like an empty list and reporting a green run over a broken one.
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
