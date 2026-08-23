#!/usr/bin/env bats

load ../../support/test_helper
load ../../support/setup_cleanup_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    target="$dotfiles_dir/support/setup/claude/claude-plugins.sh"
}

teardown() {
    teardown_dotfiles_fixture
}

@test "an installed user-scope plugin not declared in claude-plugins.sh is uninstalled" {
    # Arrange
    given_fake_claude \
        '[{"id":"agent-skills@addy-agent-skills","scope":"user"},{"id":"foo@bar","scope":"user"}]' \
        ""

    # Act
    run call_cleanup_function "$target" claude_plugins_cleanup

    # Assert
    assert_success
    assert_binary_called_with_substring claude "plugin uninstall foo@bar"
    assert_binary_not_called_with_substring claude "plugin uninstall agent-skills@addy-agent-skills"
}

@test "a project-scoped plugin is left alone even when its id isn't declared" {
    # Arrange
    given_fake_claude '[{"id":"foo@bar","scope":"project"}]' ""

    # Act
    run call_cleanup_function "$target" claude_plugins_cleanup

    # Assert
    assert_success
    assert_binary_not_called_with_substring claude "plugin uninstall foo@bar"
}

@test "a configured user-scope MCP server not declared in claude-plugins.sh is removed" {
    # Arrange
    given_fake_claude '[]' \
        "chrome-devtools: npx -y chrome-devtools-mcp@latest --isolated
undeclared-server: some-mcp-command" \
        chrome-devtools "Scope: User config" \
        undeclared-server "Scope: User config"

    # Act
    run call_cleanup_function "$target" claude_plugins_cleanup

    # Assert
    assert_success
    assert_binary_called_with_substring claude "mcp remove undeclared-server -s user"
    assert_binary_not_called_with_substring claude "mcp remove chrome-devtools -s user"
}

@test "a project-scoped MCP server is left alone even when its name isn't declared" {
    # Arrange
    given_fake_claude '[]' \
        "project-server: some-mcp-command" \
        project-server "Scope: Project config (.mcp.json)"

    # Act
    run call_cleanup_function "$target" claude_plugins_cleanup

    # Assert
    assert_success
    assert_binary_not_called_with_substring claude "mcp remove project-server"
}

@test "no undeclared plugins or MCP servers reports a clean state without removing anything" {
    # Arrange
    given_fake_claude \
        '[{"id":"agent-skills@addy-agent-skills","scope":"user"}]' \
        "chrome-devtools: npx -y chrome-devtools-mcp@latest --isolated" \
        chrome-devtools "Scope: User config"

    # Act
    run call_cleanup_function "$target" claude_plugins_cleanup

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
    run call_cleanup_function "$target" claude_plugins_cleanup

    # Assert
    assert_success
    assert_output_contains "Could not read installed Claude Code plugins, skipping their cleanup"
    assert_output_contains "Could not read configured MCP servers, skipping their cleanup"
    assert_binary_not_called_with_substring claude "plugin uninstall"
    assert_binary_not_called_with_substring claude "mcp remove"
}

@test "cleanup is skipped entirely when the claude CLI is not installed" {
    # Act
    PATH="/usr/bin:/bin" run call_cleanup_function "$target" claude_plugins_cleanup

    # Assert
    assert_success
    # If the `command -v claude` guard failed to return early, the reads below it would still
    # fail (claude is genuinely absent from this restricted PATH) and these warnings would
    # appear, so their absence is what proves the guard fired.
    assert_output_does_not_contain "Could not read installed Claude Code plugins"
    assert_output_does_not_contain "Could not read configured MCP servers"
}
