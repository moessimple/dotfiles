#!/bin/bash

# Herd normally creates a PHP version's debug.ini through its GUI Xdebug toggle.
# Unattended setup instead copies Herd's template for every installed PHP
# version. The configuration is shared by all Herd projects using that version,
# so it must not depend on one project's setup order.
step "Installing Herd's Xdebug debug.ini for installed PHP versions"

HERD_DEBUG_TEMPLATE="/Applications/Herd.app/Contents/Resources/config/php/debug.ini"
HERD_PHP_CONFIG_DIR="$HOME/Library/Application Support/Herd/config/php"

if [ -f "$HERD_DEBUG_TEMPLATE" ]; then
    while IFS= read -r version; do
        version_slug="${version//./}"
        debug_dir="$HERD_PHP_CONFIG_DIR/$version_slug/debug"
        debug_ini="$debug_dir/debug.ini"
        # Hardcoded to arm64: every machine these dotfiles run on is Apple Silicon.
        xdebug_extension="/Applications/Herd.app/Contents/Resources/xdebug/xdebug-$version_slug-arm64.so"

        if [ ! -f "$debug_ini" ]; then
            if [ ! -f "$xdebug_extension" ]; then
                warn "Herd has no Xdebug build for PHP $version yet, skipping its debug.ini"
                continue
            fi
            mkdir -p "$debug_dir" \
                || error "Could not create the Herd debug configuration directory for PHP $version"
            sed "s#XDEBUG_PATH#$xdebug_extension#" "$HERD_DEBUG_TEMPLATE" > "$debug_ini" \
                || error "Could not install the Herd debug configuration for PHP $version"
        fi
    done < <(herd php:list --json | jq -r '.[] | select(.installed) | .version')
    success "Herd Xdebug debug.ini installed"
else
    warn "Herd's debug.ini template was not found, skipping Xdebug debug.ini setup"
fi
