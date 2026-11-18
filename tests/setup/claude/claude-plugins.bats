#!/usr/bin/env bats

load ../../support/test_helper
load ../../support/setup_cleanup_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    test_home="$fixture/home"
    mkdir -p "$test_home/.claude"
    cp "$dotfiles_dir/home/.claude/settings.json" "$test_home/.claude/settings.json"
    target="$dotfiles_dir/support/setup/claude/claude-plugins.sh"
    given_setup_script_pinned CHROME_DEVTOOLS_MCP_VERSION 1.12.0
}

teardown() {
    teardown_dotfiles_fixture
}

# Prints each marketplace named after the @ of a CLAUDE_PLUGINS entry in <plugins file> that has no
# extraKnownMarketplaces entry in <settings file>.
list_plugin_marketplaces_missing_from_settings() {
    local plugins_file="$1" settings_file="$2"
    bash -c 'source "$1"; printf "%s\n" "${CLAUDE_PLUGINS[@]#*@}"' bash "$plugins_file" \
        | grep -vxF -f <(jq -r '.extraKnownMarketplaces | keys[]' "$settings_file") || true
}

@test "sourcing claude-plugins.sh only defines its functions and runs no claude command" {
    # Arrange
    given_fake_claude '[]' ""

    # Act
    run run_setup_script "$target"

    # Assert
    assert_success
    [ -z "$output" ]
    assert_binary_not_called claude
}

@test "a chrome-devtools MCP server on another version is registered again with the pinned version" {
    # Arrange
    given_fake_claude '[]' "chrome-devtools: npx -y chrome-devtools-mcp@latest --isolated" \
        chrome-devtools "Scope: User config
  Args: -y chrome-devtools-mcp@latest --isolated"

    # Act
    run call_setup_function "$target" install_claude_plugins

    # Assert
    assert_success
    assert_binary_called_with_substring claude "mcp remove chrome-devtools -s user"
    assert_binary_called_with_substring claude "mcp add chrome-devtools --scope user -- npx -y chrome-devtools-mcp@1.12.0 --isolated"
    assert_binary_not_called_with_substring claude "chrome-devtools-mcp@latest"
}

@test "a chrome-devtools MCP server already on the pinned version is left as it is" {
    # Arrange
    given_fake_claude '[]' "chrome-devtools: npx -y chrome-devtools-mcp@1.12.0 --isolated" \
        chrome-devtools "Scope: User config
  Args: -y chrome-devtools-mcp@1.12.0 --isolated"

    # Act
    run call_setup_function "$target" install_claude_plugins

    # Assert
    assert_success
    assert_binary_not_called_with_substring claude "mcp remove chrome-devtools"
    assert_binary_not_called_with_substring claude "mcp add chrome-devtools"
}

@test "a missing chrome-devtools MCP server is registered with the pinned version" {
    # Arrange
    given_fake_claude '[]' ""

    # Act
    run call_setup_function "$target" install_claude_plugins

    # Assert
    assert_success
    assert_binary_not_called_with_substring claude "mcp remove chrome-devtools"
    assert_binary_called_with_substring claude "mcp add chrome-devtools --scope user -- npx -y chrome-devtools-mcp@1.12.0 --isolated"
}

@test "every plugin marketplace is added before the plugins are installed" {
    # Arrange
    given_fake_claude '[]' ""

    # Act
    run call_setup_function "$target" install_claude_plugins

    # Assert
    assert_success
    assert_binary_called_with claude "plugin marketplace add https://github.com/addyosmani/agent-skills"
    assert_binary_called_with claude "plugin marketplace add https://github.com/laravel/claude-code"
    assert_binary_called_with claude "plugin marketplace add https://github.com/vercel-labs/agent-browser"
    assert_binary_called_with claude "plugin marketplace add https://github.com/anthropics/claude-plugins-official"
    assert_binary_called_with claude "plugin marketplace add https://github.com/pbakaus/impeccable"
}

@test "plugin installation preserves known marketplaces without registering them again" {
    # Arrange
    given_fake_claude '[]' ""
    given_claude_knows_marketplaces https://github.com/anthropics/claude-plugins-official.git

    # Act
    run call_setup_function "$target" install_claude_plugins

    # Assert
    assert_success
    assert_binary_not_called_with_substring claude "plugin marketplace add https://github.com/anthropics/claude-plugins-official"
    assert_binary_called_with claude "plugin marketplace add https://github.com/laravel/claude-code"
}

@test "plugin installation disables automatic updates after registering a new marketplace" {
    # Arrange
    given_fake_claude '[]' ""
    given_settings_linked_from_repository_with_marketplace https://github.com/pbakaus/impeccable.git

    # Act
    run call_setup_function "$target" install_claude_plugins

    # Assert
    assert_success
    assert_marketplace_auto_update_off https://github.com/pbakaus/impeccable.git
    assert_settings_still_linked_into_repository
}

@test "plugin installation warns and registers no marketplaces when their installed list cannot be read" {
    # Arrange
    given_fake_claude '[]' ""
    given_claude_failing_to_list_marketplaces

    # Act
    run call_setup_function "$target" install_claude_plugins

    # Assert
    assert_success
    assert_output_contains "WARN: Could not list the plugin marketplaces, skipping adding them"
    assert_binary_not_called_with_substring claude "plugin marketplace add"
}

@test "every plugin marketplace has Claude Code's own auto-update turned off in settings.json" {
    # Arrange
    given_fake_claude '[]' ""
    settings="$dotfiles_dir/home/.claude/settings.json"

    # Act
    run jq -r '.extraKnownMarketplaces | to_entries[] | select(.value.autoUpdate != false) | .key' "$settings"

    # Assert
    assert_success
    assert_output_equals ""
}

@test "every declared plugin comes from a marketplace declared in settings.json" {
    # Act
    run list_plugin_marketplaces_missing_from_settings "$target" "$dotfiles_dir/home/.claude/settings.json"

    # Assert
    assert_success
    assert_output_equals ""
}

@test "installing plugins announces its own step" {
    # Arrange
    given_fake_claude '[]' ""

    # Act
    run call_setup_function "$target" install_claude_plugins

    # Assert
    assert_success
    assert_output_contains "STEP: Installing Claude Code plugins and MCP servers"
}

@test "a declared plugin that is already installed is not installed again" {
    # Arrange
    given_fake_claude '[{"id":"agent-skills@addy-agent-skills","scope":"user"}]' ""

    # Act
    run call_setup_function "$target" install_claude_plugins

    # Assert
    assert_success
    assert_binary_not_called_with_substring claude "plugin install agent-skills@addy-agent-skills"
    assert_binary_called_with claude "plugin install laravel@laravel"
}

@test "a plugin that cannot be installed is reported as a warning" {
    # Arrange
    given_fake_claude '[]' ""
    given_claude_failing_to_install_plugins

    # Act
    run call_setup_function "$target" install_claude_plugins

    # Assert
    assert_success
    assert_output_contains "WARN: Could not install laravel@laravel"
}

@test "plugin installation warns and attempts all declared plugins when the installed list cannot be read" {
    # Arrange
    given_fake_claude_failing_to_report_plugins_and_mcp_servers

    # Act
    run call_setup_function "$target" install_claude_plugins

    # Assert
    assert_success
    assert_output_contains "WARN: Could not read installed Claude Code plugins, installing every declared one"
    assert_binary_called_with claude "plugin install agent-skills@addy-agent-skills"
    assert_binary_called_with claude "plugin install laravel@laravel"
}

@test "an installed user-scope plugin not declared in claude-plugins.sh is uninstalled" {
    # Arrange
    given_fake_claude \
        '[{"id":"agent-skills@addy-agent-skills","scope":"user"},{"id":"foo@bar","scope":"user"}]' \
        ""

    # Act
    run call_cleanup_function "$target" clean_up_claude_plugins

    # Assert
    assert_success
    assert_binary_called_with_substring claude "plugin uninstall foo@bar"
    assert_binary_not_called_with_substring claude "plugin uninstall agent-skills@addy-agent-skills"
    assert_output_does_not_contain "No undeclared Claude Code plugins or MCP servers found"
}

@test "a plugin declared in LOCAL_PLUGINS is left alone even though it isn't in CLAUDE_PLUGINS" {
    # Arrange
    given_fake_claude \
        '[{"id":"agent-skills@addy-agent-skills","scope":"user"},{"id":"laravel-lsp@skills-dir","scope":"user"}]' \
        ""

    # Act
    run call_cleanup_function "$target" clean_up_claude_plugins

    # Assert
    assert_success
    assert_output_contains "No undeclared Claude Code plugins or MCP servers found"
    assert_binary_not_called_with_substring claude "plugin uninstall laravel-lsp@skills-dir"
}

@test "plugin cleanup uninstalls an undeclared skills-directory plugin" {
    # Arrange
    given_fake_claude \
        '[{"id":"agent-skills@addy-agent-skills","scope":"user"},{"id":"stray-lsp@skills-dir","scope":"user"}]' \
        ""

    # Act
    run call_cleanup_function "$target" clean_up_claude_plugins

    # Assert
    assert_success
    assert_binary_called_with_substring claude "plugin uninstall stray-lsp@skills-dir"
}

@test "a project-scoped plugin is left alone even when its id isn't declared" {
    # Arrange
    given_fake_claude '[{"id":"foo@bar","scope":"project"}]' ""

    # Act
    run call_cleanup_function "$target" clean_up_claude_plugins

    # Assert
    assert_success
    assert_binary_not_called_with_substring claude "plugin uninstall foo@bar"
}

@test "a configured user-scope MCP server not declared in claude-plugins.sh is removed" {
    # Arrange
    given_fake_claude '[]' \
        "chrome-devtools: npx -y chrome-devtools-mcp@1.12.0 --isolated
undeclared-server: some-mcp-command" \
        chrome-devtools "Scope: User config
  Args: -y chrome-devtools-mcp@1.12.0 --isolated" \
        undeclared-server "Scope: User config"

    # Act
    run call_cleanup_function "$target" clean_up_claude_plugins

    # Assert
    assert_success
    assert_binary_called_with_substring claude "mcp remove undeclared-server -s user"
    assert_binary_not_called_with_substring claude "mcp remove chrome-devtools -s user"
    assert_output_does_not_contain "No undeclared Claude Code plugins or MCP servers found"
}

@test "a project-scoped MCP server is left alone even when its name isn't declared" {
    # Arrange
    given_fake_claude '[]' \
        "project-server: some-mcp-command" \
        project-server "Scope: Project config (.mcp.json)"

    # Act
    run call_cleanup_function "$target" clean_up_claude_plugins

    # Assert
    assert_success
    assert_binary_not_called_with_substring claude "mcp remove project-server"
}

@test "no undeclared plugins or MCP servers reports a clean state without removing anything" {
    # Arrange
    given_fake_claude \
        '[{"id":"agent-skills@addy-agent-skills","scope":"user"}]' \
        "chrome-devtools: npx -y chrome-devtools-mcp@1.12.0 --isolated" \
        chrome-devtools "Scope: User config
  Args: -y chrome-devtools-mcp@1.12.0 --isolated"

    # Act
    run call_cleanup_function "$target" clean_up_claude_plugins

    # Assert
    assert_success
    assert_output_contains "No undeclared Claude Code plugins or MCP servers found"
    assert_binary_not_called_with_substring claude "plugin uninstall"
    assert_binary_not_called_with_substring claude "mcp remove"
}

@test "a failed read of installed plugins and MCP servers skips cleanup instead of removing everything" {
    # Arrange
    given_fake_claude_failing_to_report_plugins_and_mcp_servers

    # Act
    run call_cleanup_function "$target" clean_up_claude_plugins

    # Assert
    assert_success
    assert_output_contains "Could not read installed Claude Code plugins, skipping their cleanup"
    assert_output_contains "Could not read configured MCP servers, skipping their cleanup"
    assert_binary_not_called_with_substring claude "plugin uninstall"
    assert_binary_not_called_with_substring claude "mcp remove"
}

@test "an unreadable MCP server list is reported instead of a clean state, while plugins are still checked" {
    # Arrange
    given_fake_claude '[{"id":"agent-skills@addy-agent-skills","scope":"user"},{"id":"foo@bar","scope":"user"}]' ""
    given_claude_failing_to_list_mcp_servers

    # Act
    run call_cleanup_function "$target" clean_up_claude_plugins

    # Assert
    assert_success
    assert_output_contains "Could not read configured MCP servers, skipping their cleanup"
    assert_binary_called_with_substring claude "plugin uninstall foo@bar"
    assert_output_does_not_contain "No undeclared Claude Code plugins or MCP servers found"
}

@test "cleanup is skipped entirely when the claude CLI is not installed" {
    # Act
    PATH="/usr/bin:/bin" run call_cleanup_function "$target" clean_up_claude_plugins

    # Assert
    assert_success
    # If the `command -v claude` guard failed to return early, the reads below it would still
    # fail (claude is genuinely absent from this restricted PATH) and these warnings would
    # appear, so their absence is what proves the guard fired.
    assert_output_does_not_contain "Could not read installed Claude Code plugins"
    assert_output_does_not_contain "Could not read configured MCP servers"
}

@test "marketplace installation reads the declaration from settings instead of a second list" {
    given_fake_claude '[]' ""
    given_settings_linked_from_repository_with_marketplace https://example.invalid/custom.git

    run call_setup_function "$target" install_claude_plugins

    assert_success
    assert_binary_called_with claude "plugin marketplace add https://example.invalid/custom"
    assert_binary_not_called_with_substring claude "plugin marketplace add https://github.com/laravel"
}

@test "an undeclared marketplace is removed while declared marketplaces are retained" {
    given_fake_claude '[]' ""
    printf '%s\n' '[{"name":"laravel"},{"name":"stray"}]' >"$fake_bin/known-marketplaces.json"

    run call_cleanup_function "$target" clean_up_claude_plugins

    assert_success
    assert_binary_called_with claude "plugin marketplace remove stray"
    assert_binary_not_called_with_substring claude "plugin marketplace remove laravel"
    assert_output_contains "Removing undeclared marketplace: stray"
}

@test "unreadable marketplace declarations skip marketplace additions and removals" {
    given_fake_claude '[]' ""
    printf '%s\n' '[{"name":"stray"}]' >"$fake_bin/known-marketplaces.json"
    printf 'invalid json\n' >"$test_home/.claude/settings.json"

    run call_setup_function "$target" install_claude_plugins clean_up_claude_plugins

    assert_success
    assert_output_contains "Could not read declared plugin marketplaces"
    assert_binary_not_called_with_substring claude "plugin marketplace add"
    assert_binary_not_called_with_substring claude "plugin marketplace remove"
    assert_output_does_not_contain "No undeclared Claude Code plugins or MCP servers found"
}

@test "an unreadable marketplace listing skips marketplace removal" {
    given_fake_claude '[]' ""
    given_claude_failing_to_list_marketplaces

    run call_cleanup_function "$target" clean_up_claude_plugins

    assert_success
    assert_output_contains "Could not read configured plugin marketplaces"
    assert_binary_not_called_with_substring claude "plugin marketplace remove"
    assert_output_does_not_contain "No undeclared Claude Code plugins or MCP servers found"
}

@test "a malformed marketplace declaration is not treated as an empty desired state" {
    given_fake_claude '[]' ""
    printf '%s\n' '[{"name":"stray"}]' >"$fake_bin/known-marketplaces.json"
    printf 'null\n' >"$test_home/.claude/settings.json"

    run call_cleanup_function "$target" clean_up_claude_plugins

    assert_success
    assert_output_contains "Could not read declared plugin marketplaces"
    assert_binary_not_called_with_substring claude "plugin marketplace remove"
}

@test "a malformed marketplace listing is rejected before any marketplace is removed" {
    given_fake_claude '[]' ""
    printf '%s\n' '[{"name":"stray"},{}]' >"$fake_bin/known-marketplaces.json"

    run call_cleanup_function "$target" clean_up_claude_plugins

    assert_success
    assert_output_contains "Could not read configured plugin marketplaces"
    assert_binary_not_called_with_substring claude "plugin marketplace remove"
}

@test "empty or wrongly typed settings never authorize marketplace removal" {
    given_fake_claude '[]' ""
    printf '%s\n' '[{"name":"stray"}]' >"$fake_bin/known-marketplaces.json"
    local settings
    for settings in '' '{"extraKnownMarketplaces":false}' '{} {}' '{"extraKnownMarketplaces":[]}'; do
        printf '%s\n' "$settings" >"$test_home/.claude/settings.json"
        run call_cleanup_function "$target" clean_up_claude_plugins
        assert_success
        assert_output_contains "Could not read declared plugin marketplaces"
        assert_binary_not_called_with_substring claude "plugin marketplace remove"
    done
}

@test "marketplaces needed by project or local plugins are retained" {
    given_fake_claude '[{"id":"project-plugin@stray","scope":"project"},{"id":"local-plugin@other","scope":"local"}]' ""
    printf '%s\n' '[{"name":"stray"},{"name":"other"}]' >"$fake_bin/known-marketplaces.json"

    run call_cleanup_function "$target" clean_up_claude_plugins

    assert_success
    assert_binary_not_called_with_substring claude "plugin marketplace remove"
    assert_output_contains "Keeping marketplace stray"
    assert_output_contains "Keeping marketplace other"
}

@test "a failed plugin listing also skips cascading marketplace removal" {
    given_fake_claude '[]' ""
    touch "$fake_bin/plugin-list-fails"
    printf '%s\n' '[{"name":"stray"}]' >"$fake_bin/known-marketplaces.json"

    run call_cleanup_function "$target" clean_up_claude_plugins

    assert_success
    assert_output_contains "Could not read installed Claude Code plugins"
    assert_binary_not_called_with_substring claude "plugin marketplace remove"
}

@test "marketplace cleanup leaves the current project's local declaration untouched" {
    given_fake_claude '[]' ""
    printf '%s\n' '[{"name":"stray"}]' >"$fake_bin/known-marketplaces.json"
    mkdir -p "$fixture/project/.claude"
    printf 'project declaration\n' >"$fixture/project/.claude/settings.local.json"
    cat >>"$fake_bin/claude" <<'SCRIPT'
if [[ "$*" == "plugin marketplace remove stray" ]]; then
    rm -f .claude/settings.local.json
fi
SCRIPT
    cleanup_in_project() (
        cd "$fixture/project"
        call_cleanup_function "$target" clean_up_claude_plugins
    )

    run cleanup_in_project

    assert_success
    assert_binary_called_with claude "plugin marketplace remove stray"
    assert_file_content "$fixture/project/.claude/settings.local.json" "project declaration"
}
