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
herd_debug_ini_install() {
    step "Installing Herd's Xdebug ini files for installed PHP versions"

    local installed_versions version version_slug debug_dir debug_ini xdebug_extension always_ini write_failed
    # HERD_RESOURCES_DIR lets the Bats suite point the Herd.app lookups at a fixture tree.
    local resources_dir="${HERD_RESOURCES_DIR:-/Applications/Herd.app/Contents/Resources}"
    local debug_template="$resources_dir/config/php/debug.ini"
    local php_config_dir="$HOME/Library/Application Support/Herd/config/php"

    if [[ ! -f "$debug_template" ]]; then
        warn "Herd's debug.ini template was not found, skipping Xdebug debug.ini setup"
    elif ! installed_versions=$(
        set -o pipefail
        herd php:list --json | jq -r '.[] | select(.installed) | .version'
    ); then
        warn "Could not read Herd's PHP versions, skipping Xdebug ini setup"
    else
        write_failed=0
        while IFS= read -r version; do
            [[ -n "$version" ]] || continue
            version_slug="${version//./}"
            debug_dir="$php_config_dir/$version_slug/debug"
            debug_ini="$debug_dir/debug.ini"
            # Hardcoded to arm64: every machine these dotfiles run on is Apple Silicon.
            xdebug_extension="$resources_dir/xdebug/xdebug-$version_slug-arm64.so"

            if [[ ! -f "$xdebug_extension" ]]; then
                note "Herd has no Xdebug build for PHP $version yet, skipping its Xdebug ini files"
                continue
            fi

            if ! mkdir -p "$debug_dir"; then
                warn "Could not create the Herd debug configuration directory for PHP $version"
                write_failed=1
                continue
            fi
            if ! sed "s#XDEBUG_PATH#$xdebug_extension#" "$debug_template" >"$debug_ini"; then
                warn "Could not install the Herd debug configuration for PHP $version"
                write_failed=1
            fi

            always_ini="$php_config_dir/$version_slug/xdebug.ini"
            if ! printf 'zend_extension=%s\nxdebug.mode=off\n' "$xdebug_extension" >"$always_ini"; then
                warn "Could not install the always-loaded Xdebug ini for PHP $version"
                write_failed=1
            fi
        done <<<"$installed_versions"
        if ((write_failed == 0)); then
            success "Herd Xdebug ini files installed"
        fi
    fi
}
