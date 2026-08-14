#!/bin/bash

CLAUDE_PLUGINS=(
    "agent-skills@addy-agent-skills"
    "laravel@laravel"
    "agent-browser@agent-browser"
    "claude-md-management@claude-plugins-official"
)

# User-scope MCP servers this file configures. Each has its own `claude mcp add` args below
# (scope, command, flags), so this only tracks the names, for claude_plugins_cleanup.
CLAUDE_MCP_SERVERS=(
    chrome-devtools
)

if command -v claude &>/dev/null; then
    claude plugin marketplace add https://github.com/addyosmani/agent-skills 2>/dev/null || warn "addy-agent-skills marketplace already added"
    claude plugin marketplace add https://github.com/laravel/claude-code 2>/dev/null || warn "laravel marketplace already added"
    claude plugin marketplace add https://github.com/vercel-labs/agent-browser 2>/dev/null || warn "agent-browser marketplace already added"
    claude plugin marketplace add https://github.com/anthropics/claude-plugins-official 2>/dev/null || warn "claude-plugins-official marketplace already added"
    for plugin in "${CLAUDE_PLUGINS[@]}"; do
        claude plugin install "$plugin" 2>/dev/null || warn "$plugin already installed"
    done
    claude mcp add chrome-devtools --scope user -- npx -y chrome-devtools-mcp@latest --isolated 2>/dev/null || warn "chrome-devtools MCP server already configured"
    success "Claude Code plugins and MCP servers installed"
else
    warn "claude CLI not found — install Claude Code first, then run: claude plugin install ${CLAUDE_PLUGINS[*]}"
fi

# Removes any installed plugin or configured MCP server that isn't declared above. Same
# idea as `brew bundle cleanup --force` and claude_skills_cleanup in claude-skills.sh.
claude_plugins_cleanup() {
    command -v claude &>/dev/null || return 0

    step "Checking for undeclared Claude Code plugins and MCP servers"

    local name found_undeclared=0 read_failed=0

    # Only user-scope plugins are ours to manage, same reasoning as for the MCP servers below.
    # pipefail, and the assignment kept out of `local`, so a failing claude or a missing jq
    # surfaces instead of looking like an empty list and reporting a green run over a broken one.
    local installed_plugins
    if ! installed_plugins=$(set -o pipefail; claude plugin list --json 2>/dev/null | jq -r '.[] | select(.scope == "user") | .id'); then
        read_failed=1
        warn "Could not read installed Claude Code plugins, skipping their cleanup"
    else
        while IFS= read -r name; do
            [ -n "$name" ] || continue
            if ! printf '%s\n' "${CLAUDE_PLUGINS[@]}" | grep -qxF "$name"; then
                found_undeclared=1
                warn "Uninstalling undeclared plugin: $name (not in claude-plugins.sh)"
                claude plugin uninstall "$name" || warn "Could not uninstall $name, remove it manually"
            fi
        done <<< "$installed_plugins"
    fi

    # No pipefail here: grep exits 1 when no server is configured at all, which is a valid
    # empty state rather than a failure, so only `claude mcp list` itself is checked.
    local mcp_output
    if ! mcp_output=$(claude mcp list 2>/dev/null); then
        read_failed=1
        warn "Could not read configured MCP servers, skipping their cleanup"
    else
        local mcp_names
        mcp_names=$(printf '%s\n' "$mcp_output" | grep -oE '^[a-zA-Z0-9_-]+:' | tr -d ':')
        while IFS= read -r name; do
            [ -n "$name" ] || continue
            # Only user-scope servers are ours to manage. Project-scoped ones belong to
            # whatever project added them, `claude mcp add` defaults to project scope.
            claude mcp get "$name" 2>/dev/null | grep -q "Scope: User config" || continue
            if ! printf '%s\n' "${CLAUDE_MCP_SERVERS[@]}" | grep -qxF "$name"; then
                found_undeclared=1
                warn "Removing undeclared MCP server: $name (not in claude-plugins.sh)"
                claude mcp remove "$name" -s user || warn "Could not remove $name, remove it manually"
            fi
        done <<< "$mcp_names"
    fi

    # This cleanup carries on with whichever half it could read, so unlike the other three it
    # cannot return early and has to track the read failure to keep from reporting a clean state.
    # An `if`, not `&&`, which would return 1 after a removal and trip `set -e` in bin/update.sh
    if [ "$found_undeclared" -eq 0 ] && [ "$read_failed" -eq 0 ]; then
        success "No undeclared Claude Code plugins or MCP servers found"
    fi
}
