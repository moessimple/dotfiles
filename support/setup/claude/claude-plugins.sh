#!/bin/bash

CLAUDE_PLUGINS=(
    "agent-skills@addy-agent-skills"
    "laravel@laravel"
    "agent-browser@agent-browser"
    "claude-md-management@claude-plugins-official"
    "typescript-lsp@claude-plugins-official"
    "impeccable@impeccable"
)

# LSP configs written directly in this repo, living in home/.claude/skills/ with their own
# .claude-plugin/plugin.json, rather than installed via `claude plugin install`. Claude Code
# auto-detects them from that directory (id suffix @skills-dir) and lists them as user-scope
# plugins, so clean_up_claude_plugins needs to recognize them as intentional. `claude plugin
# uninstall` always fails on them anyway, since skills-dir plugins have no marketplace backing.
LOCAL_PLUGINS=(
    "laravel-lsp@skills-dir"
    "php-lsp-herd@skills-dir"
)

# User-scope MCP servers this file configures. Each has its own `claude mcp add` args below
# (scope, command, flags), so this only tracks the names, for clean_up_claude_plugins.
CLAUDE_MCP_SERVERS=(
    chrome-devtools
)

# Pinned because npx runs the package with full user rights on every server start. The package
# has no runtime dependencies, so this pin fixes all code that runs. Raise it deliberately.
CHROME_DEVTOOLS_MCP_VERSION="1.13.0"

# `claude plugin marketplace add` rewrites the marketplace's extraKnownMarketplaces entry without
# "autoUpdate": false, also for one declared there before it is first cloned. Sets it again for the
# entry with git <url>. settings.json is a symlink into this repository, so it is written through
# the link rather than replaced.
disable_marketplace_auto_update() {
    local url="$1" settings="$HOME/.claude/settings.json" updated
    updated="$(jq --arg url "${url%.git}" '.extraKnownMarketplaces |= with_entries(
        if (.value.source.url // "" | sub("\\.git$"; "")) == $url then .value.autoUpdate = false else . end)' \
        "$settings" 2>/dev/null)" || return 1
    printf '%s\n' "$updated" >"$settings"
}

read_claude_marketplaces() {
    jq -es '
        if length == 1 and (.[0] | type == "object") then .[0] else error("Expected one settings object") end |
        if has("extraKnownMarketplaces") then .extraKnownMarketplaces else {} end |
        if type == "object" and all(.[];
            .source.source == "git" and (.source.url | type == "string" and length > 0))
        then . else error("Expected git marketplace declarations") end' "$HOME/.claude/settings.json"
}

install_claude_plugins() {
    local declared_marketplaces known_marketplaces marketplace installed_plugins plugin registered_mcp
    step "Installing Claude Code plugins and MCP servers"
    if command -v claude &>/dev/null; then
        # Only marketplaces Claude Code does not know yet are added, and their autoUpdate is set off
        # again afterwards: without it Claude Code updates plugins on its own and bypasses the cooldown
        # in update.sh.
        if ! declared_marketplaces="$(
            set -o pipefail
            read_claude_marketplaces | jq -r '.[].source.url | sub("\\.git$"; "")'
        )"; then
            warn "Could not read declared plugin marketplaces, skipping adding them"
        elif known_marketplaces="$(
            set -o pipefail
            claude plugin marketplace list --json 2>/dev/null | jq -r '.[] | .url // empty | sub("\\.git$"; "")'
        )"; then
            while IFS= read -r marketplace; do
                [[ -n "$marketplace" ]] || continue
                printf '%s\n' "$known_marketplaces" | grep -qxF "$marketplace" && continue
                if ! claude plugin marketplace add "$marketplace" 2>/dev/null; then
                    warn "Could not add the $marketplace marketplace"
                elif ! disable_marketplace_auto_update "$marketplace"; then
                    warn "Could not turn off auto-update for $marketplace, set \"autoUpdate\": false in ~/.claude/settings.json"
                fi
            done <<<"$declared_marketplaces"
        else
            warn "Could not list the plugin marketplaces, skipping adding them"
        fi
        # Only missing plugins are installed, so a failed install is a real problem.
        if ! installed_plugins="$(
            set -o pipefail
            claude plugin list --json 2>/dev/null | jq -r '.[] | select(.scope == "user") | .id'
        )"; then
            warn "Could not read installed Claude Code plugins, installing every declared one"
            installed_plugins=""
        fi
        for plugin in "${CLAUDE_PLUGINS[@]}"; do
            printf '%s\n' "$installed_plugins" | grep -qxF "$plugin" && continue
            claude plugin install "$plugin" || warn "Could not install $plugin"
        done
        # `claude mcp add` refuses an existing name, so a registration with another version is
        # removed first; that is how a raised version takes effect. `mcp get` fails when the server
        # is not configured yet, which under the entry points' `set -e` would end the whole run.
        registered_mcp="$(claude mcp get chrome-devtools 2>/dev/null)" || registered_mcp=""
        if [[ "$registered_mcp" != *"chrome-devtools-mcp@$CHROME_DEVTOOLS_MCP_VERSION "* ]]; then
            if [[ -n "$registered_mcp" ]]; then
                claude mcp remove chrome-devtools -s user &>/dev/null || true
            fi
            claude mcp add chrome-devtools --scope user -- npx -y "chrome-devtools-mcp@$CHROME_DEVTOOLS_MCP_VERSION" --isolated 2>/dev/null || warn "Could not configure the chrome-devtools MCP server"
        fi
        success "Claude Code plugins and MCP servers installed"
    else
        warn "claude CLI not found. Install Claude Code first, then run: claude plugin install ${CLAUDE_PLUGINS[*]}"
    fi
}

# A new upstream version of a plugin waits out the same 3-day cooldown as Composer and npm. Needs
# support/setup/claude/update-cooldown.sh sourced as well.
update_claude_plugins() {
    step "Updating Claude Code plugins"
    update_plugins_after_cooldown
    success "Claude Code plugin updates processed"
}

# Removes any installed plugin or configured MCP server that isn't declared above. Same
# idea as `brew bundle cleanup --force` and clean_up_claude_skills in claude-skills.sh.
clean_up_claude_plugins() {
    command -v claude &>/dev/null || return 0

    step "Checking for undeclared Claude Code plugins and MCP servers"

    local name found_undeclared=0 read_failed=0

    # Only user-scope plugins are ours to manage, same reasoning as for the MCP servers below.
    local installed_plugins plugin_listing
    if ! plugin_listing="$(
        set -o pipefail
        claude plugin list --json 2>/dev/null | jq -cs '
            if length == 1 and (.[0] | type == "array" and all(.[];
                (.id | type == "string") and (.scope | type == "string")))
            then .[0] else error("Expected plugin list with scopes") end'
    )"; then
        read_failed=1
        plugin_listing=""
        warn "Could not read installed Claude Code plugins, skipping their cleanup and the marketplace cleanup"
    else
        installed_plugins="$(printf '%s\n' "$plugin_listing" | jq -r '.[] | select(.scope == "user") | .id')"
        while IFS= read -r name; do
            [[ -n "$name" ]] || continue
            printf '%s\n' "${CLAUDE_PLUGINS[@]}" "${LOCAL_PLUGINS[@]}" | grep -qxF "$name" && continue

            found_undeclared=1
            note "Uninstalling undeclared plugin: $name (not in claude-plugins.sh)"
            claude plugin uninstall "$name" || warn "Could not uninstall $name, remove it manually"
        done <<<"$installed_plugins"
    fi

    local declared_marketplaces known_marketplaces
    if [[ -z "$plugin_listing" ]]; then
        : # Removing a marketplace uninstalls its plugins in every scope, which only the listing shows.
    elif ! declared_marketplaces="$(
        set -o pipefail
        read_claude_marketplaces | jq -r 'keys[]'
    )"; then
        read_failed=1
        warn "Could not read declared plugin marketplaces, skipping their cleanup"
    elif ! known_marketplaces="$(
        set -o pipefail
        claude plugin marketplace list --json 2>/dev/null | jq -rs '
            if length == 1 and (.[0] | type == "array" and all(.[];
                .name | type == "string" and length > 0))
            then .[0][].name else error("Expected marketplace list with names") end'
    )"; then
        read_failed=1
        warn "Could not read configured plugin marketplaces, skipping their cleanup"
    else
        while IFS= read -r name; do
            [[ -n "$name" ]] || continue
            printf '%s\n' "$declared_marketplaces" | grep -qxF "$name" && continue

            # Removing a marketplace also uninstalls its plugins, including project/local scopes.
            if printf '%s\n' "$plugin_listing" | jq -e --arg marketplace "$name" \
                'any(.[]; .scope != "user" and (.id | endswith("@" + $marketplace)))' >/dev/null; then
                note "Keeping marketplace $name: required by a project or local plugin"
                continue
            fi

            found_undeclared=1
            note "Removing undeclared marketplace: $name (not in settings.json)"
            # The CLI also edits declarations in its working directory; keep project settings untouched.
            (cd "$HOME" && claude plugin marketplace remove "$name") || warn "Could not remove $name, remove it manually"
        done <<<"$known_marketplaces"
    fi

    # No pipefail here: grep exits 1 when no server is configured at all, which is a valid
    # empty state rather than a failure, so only `claude mcp list` itself is checked.
    local mcp_output
    if ! mcp_output="$(claude mcp list 2>/dev/null)"; then
        read_failed=1
        warn "Could not read configured MCP servers, skipping their cleanup"
    else
        local mcp_names
        mcp_names="$(printf '%s\n' "$mcp_output" | grep -oE '^[a-zA-Z0-9_-]+:' | tr -d ':')"
        while IFS= read -r name; do
            [[ -n "$name" ]] || continue
            # Only user-scope servers are ours to manage. Project-scoped ones belong to
            # whatever project added them, `claude mcp add` defaults to project scope.
            claude mcp get "$name" 2>/dev/null | grep -q "Scope: User config" || continue
            printf '%s\n' "${CLAUDE_MCP_SERVERS[@]}" | grep -qxF "$name" && continue

            found_undeclared=1
            note "Removing undeclared MCP server: $name (not in claude-plugins.sh)"
            claude mcp remove "$name" -s user || warn "Could not remove $name, remove it manually"
        done <<<"$mcp_names"
    fi

    # The cleanup goes on with whichever half it could read, so read_failed keeps a partial
    # read from being reported as clean.
    if ((found_undeclared == 0)) && ((read_failed == 0)); then
        success "No undeclared Claude Code plugins or MCP servers found"
    fi
}
