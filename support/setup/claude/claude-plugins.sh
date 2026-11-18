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

# === Install ===

# Adds each marketplace declared in settings.json that Claude Code does not know yet, and turns its
# autoUpdate off again: without it Claude Code updates plugins on its own and bypasses the cooldown
# in update.sh.
add_missing_claude_marketplaces() {
    local declared_marketplaces known_marketplaces marketplace
    if ! declared_marketplaces="$(
        set -o pipefail
        read_claude_marketplaces | jq -r '.[].source.url | sub("\\.git$"; "")'
    )"; then
        warn "Could not read declared plugin marketplaces, skipping adding them"
        return 0
    fi
    if ! known_marketplaces="$(
        set -o pipefail
        claude plugin marketplace list --json 2>/dev/null | jq -r '.[] | .url // empty | sub("\\.git$"; "")'
    )"; then
        warn "Could not list the plugin marketplaces, skipping adding them"
        return 0
    fi

    while IFS= read -r marketplace; do
        [[ -n "$marketplace" ]] || continue
        printf '%s\n' "$known_marketplaces" | grep -qxF "$marketplace" && continue
        if ! claude plugin marketplace add "$marketplace" 2>/dev/null; then
            warn "Could not add the $marketplace marketplace"
        elif ! disable_marketplace_auto_update "$marketplace"; then
            warn "Could not turn off auto-update for $marketplace, set \"autoUpdate\": false in ~/.claude/settings.json"
        fi
    done <<<"$declared_marketplaces"
}

# Only missing plugins are installed, so a failed install is a real problem.
install_missing_claude_plugins() {
    local installed_plugins plugin
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
}

# `claude mcp add` refuses an existing name, so a registration with another version is removed
# first; that is how a raised version takes effect. `mcp get` fails when the server is not
# configured yet, which under the entry points' `set -e` would end the whole run.
configure_chrome_devtools_mcp_server() {
    local registered_mcp
    registered_mcp="$(claude mcp get chrome-devtools 2>/dev/null)" || registered_mcp=""
    if [[ "$registered_mcp" == *"chrome-devtools-mcp@$CHROME_DEVTOOLS_MCP_VERSION "* ]]; then
        return 0
    fi
    if [[ -n "$registered_mcp" ]]; then
        claude mcp remove chrome-devtools -s user &>/dev/null || true
    fi
    claude mcp add chrome-devtools --scope user -- npx -y "chrome-devtools-mcp@$CHROME_DEVTOOLS_MCP_VERSION" --isolated 2>/dev/null || warn "Could not configure the chrome-devtools MCP server"
}

install_claude_plugins() {
    step "Installing Claude Code plugins and MCP servers"
    if ! command -v claude &>/dev/null; then
        warn "claude CLI not found. Install Claude Code first, then run: claude plugin install ${CLAUDE_PLUGINS[*]}"
        return 0
    fi
    add_missing_claude_marketplaces
    install_missing_claude_plugins
    configure_chrome_devtools_mcp_server
    success "Claude Code plugins and MCP servers installed"
}

# === Update ===

# Prints the upstream state of plugin <name> in the marketplace <checkout> of <url>: the tree of its
# folder plus its marketplace entry, which can define hooks and servers itself. A source object
# naming the marketplace's own repository is its root. Fails when the plugin is not listed or its
# source is another repository, whose changes this checkout cannot see.
print_plugin_state() {
    local name="$1" checkout="$2" url="$3" entry source folder slug="" tree
    entry="$(git -C "$checkout" show HEAD:.claude-plugin/marketplace.json 2>/dev/null \
        | jq -ce --arg name "$name" 'first(.plugins[] | select(.name == $name))')" || return 1
    source="$(jq -c '.source' <<<"$entry")"
    case "$url" in
        https://github.com/*) slug="${url#https://github.com/}" && slug="${slug%.git}" ;;
    esac
    if folder="$(jq -er 'strings' <<<"$source")"; then
        folder="${folder#./}"
        folder="${folder%/}"
        [[ "$folder" != "." ]] || folder=""
    elif jq -e --arg url "${url%.git}" --arg slug "$slug" \
        '((.repo // "") == $slug and $slug != "") or (((.url // "") | sub("\\.git$"; "")) == $url)' \
        <<<"$source" >/dev/null; then
        folder=""
    else
        return 1
    fi
    tree="$(git -C "$checkout" rev-parse --verify --quiet "HEAD:$folder")" || return 1
    echo "$tree+$(printf '%s' "$entry" | git hash-object --stdin)"
}

# Updates the plugins in CLAUDE_PLUGINS of each marketplace once the upstream states of all of them
# have passed the cooldown. Claude Code itself decides whether that is a new version, so an
# unchanged plugin stays as it is. autoUpdate is off in settings.json, so the marketplace is
# refreshed first.
update_plugins_after_cooldown() {
    local marketplaces
    # pipefail, so a failed listing is reported instead of reading as "no marketplaces to check".
    if ! marketplaces="$(
        set -o pipefail
        claude plugin marketplace list --json 2>/dev/null \
            | jq -r '.[] | select(.url != null) | [.name, .url] | @tsv'
    )"; then
        warn "Could not list the plugin marketplaces, plugins not updated"
        return 0
    fi

    local name url checkout plugin state plugins all_cooled_down
    # The list arrives on fd 3, so the claude calls in the loop cannot consume it from stdin.
    while IFS=$'\t' read -r -u 3 name url; do
        [[ -n "$name" ]] || continue
        checkout="$(mktemp -d)"
        if ! git clone --quiet --filter=blob:none --no-checkout "$url" "$checkout" 2>/dev/null; then
            warn "Could not check the $name marketplace, its plugins are not updated"
            rm -rf "$checkout"
            continue
        fi
        plugins=()
        all_cooled_down=1
        # Claude Code reads a plugin's marketplace entry, which can define LSP and MCP servers and
        # hooks, from the refreshed checkout on every start, also without `claude plugin update`.
        # The refresh therefore waits until the states of all declared plugins have passed the
        # cooldown. Every state is still checked, so each one's first sighting is recorded.
        for plugin in "${CLAUDE_PLUGINS[@]}"; do
            [[ "${plugin#*@}" == "$name" ]] || continue
            if ! state="$(print_plugin_state "${plugin%@*}" "$checkout" "$url")"; then
                warn "Could not check $plugin in the $name marketplace, not updated"
                all_cooled_down=0
                continue
            fi
            has_cooled_down "$plugin" "$state" || all_cooled_down=0
            plugins+=("$plugin")
        done
        rm -rf "$checkout"
        if ((all_cooled_down != 1 || ${#plugins[@]} == 0)); then
            continue
        fi
        if ! claude plugin marketplace update "$name"; then
            warn "Could not refresh the $name marketplace, its plugins are not updated"
            continue
        fi
        for plugin in "${plugins[@]}"; do
            claude plugin update "$plugin" || warn "Could not update $plugin"
        done
    done 3<<<"$marketplaces"
}

# A new upstream version of a plugin waits out the same 3-day cooldown as Composer and npm. Needs
# support/setup/claude/update-cooldown.sh sourced as well.
update_claude_plugins() {
    step "Updating Claude Code plugins"
    update_plugins_after_cooldown
    success "Claude Code plugin updates processed"
}

# === Clean up ===

# Prints every installed plugin, in all scopes, as a JSON array of {id, scope}. Fails on any other
# shape, so an unreadable listing never looks like "nothing installed".
read_claude_plugin_listing() {
    (
        set -o pipefail
        claude plugin list --json 2>/dev/null | jq -cs '
            if length == 1 and (.[0] | type == "array" and all(.[];
                (.id | type == "string") and (.scope | type == "string")))
            then .[0] else error("Expected plugin list with scopes") end'
    )
}

# Uninstalls each user-scope plugin in <plugin listing> that is neither in CLAUDE_PLUGINS nor in
# LOCAL_PLUGINS. Only user-scope plugins are ours to manage, as with the MCP servers. Returns 1
# when it found one.
uninstall_undeclared_claude_plugins() {
    local plugin_listing="$1" installed_plugins name found_undeclared=0
    installed_plugins="$(printf '%s\n' "$plugin_listing" | jq -r '.[] | select(.scope == "user") | .id')"
    while IFS= read -r name; do
        [[ -n "$name" ]] || continue
        printf '%s\n' "${CLAUDE_PLUGINS[@]}" "${LOCAL_PLUGINS[@]}" | grep -qxF "$name" && continue

        found_undeclared=1
        note "Uninstalling undeclared plugin: $name (not in claude-plugins.sh)"
        claude plugin uninstall "$name" || warn "Could not uninstall $name, remove it manually"
    done <<<"$installed_plugins"
    return "$found_undeclared"
}

# Removes each marketplace Claude Code knows that settings.json does not declare. Removing a
# marketplace also uninstalls its plugins in every scope, so one that a project or local plugin in
# <plugin listing> comes from is kept. Returns 1 when it found one or could not read the lists.
remove_undeclared_claude_marketplaces() {
    local plugin_listing="$1" declared_marketplaces known_marketplaces name found_undeclared=0
    if ! declared_marketplaces="$(
        set -o pipefail
        read_claude_marketplaces | jq -r 'keys[]'
    )"; then
        warn "Could not read declared plugin marketplaces, skipping their cleanup"
        return 1
    fi
    if ! known_marketplaces="$(
        set -o pipefail
        claude plugin marketplace list --json 2>/dev/null | jq -rs '
            if length == 1 and (.[0] | type == "array" and all(.[];
                .name | type == "string" and length > 0))
            then .[0][].name else error("Expected marketplace list with names") end'
    )"; then
        warn "Could not read configured plugin marketplaces, skipping their cleanup"
        return 1
    fi

    while IFS= read -r name; do
        [[ -n "$name" ]] || continue
        printf '%s\n' "$declared_marketplaces" | grep -qxF "$name" && continue

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
    return "$found_undeclared"
}

# Removes each user-scope MCP server not in CLAUDE_MCP_SERVERS. Project-scoped ones belong to
# whatever project added them; `claude mcp add` defaults to project scope. Returns 1 when it found
# one or could not read the list.
remove_undeclared_mcp_servers() {
    local mcp_output mcp_names name found_undeclared=0
    if ! mcp_output="$(claude mcp list 2>/dev/null)"; then
        warn "Could not read configured MCP servers, skipping their cleanup"
        return 1
    fi
    # No pipefail here: grep exits 1 when no server is configured at all, which is a valid
    # empty state rather than a failure.
    mcp_names="$(printf '%s\n' "$mcp_output" | grep -oE '^[a-zA-Z0-9_-]+:' | tr -d ':')"

    while IFS= read -r name; do
        [[ -n "$name" ]] || continue
        claude mcp get "$name" 2>/dev/null | grep -q "Scope: User config" || continue
        printf '%s\n' "${CLAUDE_MCP_SERVERS[@]}" | grep -qxF "$name" && continue

        found_undeclared=1
        note "Removing undeclared MCP server: $name (not in claude-plugins.sh)"
        claude mcp remove "$name" -s user || warn "Could not remove $name, remove it manually"
    done <<<"$mcp_names"
    return "$found_undeclared"
}

# Removes any installed plugin, marketplace, or MCP server that isn't declared. Same idea as
# `brew bundle cleanup --force` and clean_up_claude_skills in claude-skills.sh. Each part goes on
# with whatever it could read, so the success message needs every part to be clean.
clean_up_claude_plugins() {
    command -v claude &>/dev/null || return 0

    step "Checking for undeclared Claude Code plugins and MCP servers"

    local plugin_listing all_clean=1
    if plugin_listing="$(read_claude_plugin_listing)"; then
        uninstall_undeclared_claude_plugins "$plugin_listing" || all_clean=0
        remove_undeclared_claude_marketplaces "$plugin_listing" || all_clean=0
    else
        warn "Could not read installed Claude Code plugins, skipping their cleanup and the marketplace cleanup"
        all_clean=0
    fi
    remove_undeclared_mcp_servers || all_clean=0

    if ((all_clean == 1)); then
        success "No undeclared Claude Code plugins or MCP servers found"
    fi
}
