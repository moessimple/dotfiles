#!/bin/bash

# Herd normally creates a PHP version's debug.ini through its GUI Xdebug toggle.
# Unattended setup instead copies Herd's template for every installed PHP
# version. The configuration is shared by all Herd projects using that version,
# so it must not depend on one project's setup order.
# Both ini files are managed here and rewritten on every run to correct drift.
#
# It also drops an always-loaded xdebug.ini in each version's ini scan dir with
# xdebug.mode=off: Xdebug is then present in every PHP process (including the
# children Composer spawns for pest), at near-zero cost, and any command that
# exports XDEBUG_MODE (a project's `composer test` sets XDEBUG_MODE=coverage)
# activates it for that run only. This is what Pest's coverage-driver detection
# expects and mirrors CI; the debug.ini above stays for `herd debug`.
step "Installing Herd's Xdebug ini files for installed PHP versions"

# Overridable so the Bats suite can point the Herd.app lookups at a fixture tree.
HERD_RESOURCES_DIR="${HERD_RESOURCES_DIR:-/Applications/Herd.app/Contents/Resources}"
HERD_DEBUG_TEMPLATE="$HERD_RESOURCES_DIR/config/php/debug.ini"
HERD_PHP_CONFIG_DIR="$HOME/Library/Application Support/Herd/config/php"

if [ ! -f "$HERD_DEBUG_TEMPLATE" ]; then
    warn "Herd's debug.ini template was not found, skipping Xdebug debug.ini setup"
elif ! installed_versions=$(
    set -o pipefail
    herd php:list --json | jq -r '.[] | select(.installed) | .version'
); then
    # pipefail, and the result captured before the loop, so a failing `herd` or a
    # jq parse error surfaces here instead of an empty version list that would
    # process nothing and still report success.
    warn "Could not read Herd's PHP versions, skipping Xdebug ini setup"
else
    write_failed=0
    while IFS= read -r version; do
        [ -n "$version" ] || continue
        version_slug="${version//./}"
        debug_dir="$HERD_PHP_CONFIG_DIR/$version_slug/debug"
        debug_ini="$debug_dir/debug.ini"
        # Hardcoded to arm64: every machine these dotfiles run on is Apple Silicon.
        xdebug_extension="$HERD_RESOURCES_DIR/xdebug/xdebug-$version_slug-arm64.so"

        if [ ! -f "$xdebug_extension" ]; then
            note "Herd has no Xdebug build for PHP $version yet, skipping its Xdebug ini files"
            continue
        fi

        if ! mkdir -p "$debug_dir"; then
            warn "Could not create the Herd debug configuration directory for PHP $version"
            write_failed=1
            continue
        fi
        if ! sed "s#XDEBUG_PATH#$xdebug_extension#" "$HERD_DEBUG_TEMPLATE" >"$debug_ini"; then
            warn "Could not install the Herd debug configuration for PHP $version"
            write_failed=1
        fi

        always_ini="$HERD_PHP_CONFIG_DIR/$version_slug/xdebug.ini"
        if ! printf 'zend_extension=%s\nxdebug.mode=off\n' "$xdebug_extension" >"$always_ini"; then
            warn "Could not install the always-loaded Xdebug ini for PHP $version"
            write_failed=1
        fi
    done <<<"$installed_versions"
    if [ "$write_failed" -eq 0 ]; then
        success "Herd Xdebug ini files installed"
    fi
fi
