#!/usr/bin/env bats

load ../../support/test_helper
load ../../support/plugin_review_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    test_home="$fixture/home"
    mkdir -p "$test_home/.claude/plugins"
}

teardown() {
    teardown_dotfiles_fixture
}

@test "a plugin update is assessed by Claude and applied on yes" {
    # Arrange
    given_marketplace_with_plugin_change
    given_fake_claude_reviewing "VERDICT: OK"

    # Act
    run call_review_plugin_update <<< "y"

    # Assert
    assert_success
    assert_output_contains "VERDICT: OK"
    assert_binary_called_with claude "plugin marketplace update laravel"
    assert_binary_called_with claude "plugin update laravel@laravel"
    assert_output_contains "SUCCESS: laravel@laravel updated"
}

# Technical contract: the diff is untrusted, so the reviewer gets no tools and no plugin hooks.
@test "Claude reviews only the plugin's own directory, without tools or hooks" {
    # Arrange
    given_marketplace_with_plugin_change
    given_fake_claude_reviewing "VERDICT: OK"

    # Act
    run call_review_plugin_update <<< "n"

    # Assert
    assert_success
    assert_binary_called_with claude "-p --tools  --no-session-persistence --settings {\"disableAllHooks\":true}"
    assert_review_input_contains "laravel/skills/SKILL.md"
    assert_review_input_does_not_contain "other-plugin/"
}

@test "a plugin update is left alone on no" {
    # Arrange
    given_marketplace_with_plugin_change
    given_fake_claude_reviewing "VERDICT: DANGER"

    # Act
    run call_review_plugin_update <<< "n"

    # Assert
    assert_success
    assert_output_contains "VERDICT: DANGER"
    assert_binary_not_called_with_substring claude "plugin update laravel@laravel"
    assert_output_contains "Left as is."
}

@test "a plugin update is left alone when no answer arrives" {
    # Arrange
    given_marketplace_with_plugin_change
    given_fake_claude_reviewing "VERDICT: OK"

    # Act
    run call_review_plugin_update < /dev/null

    # Assert
    assert_success
    assert_binary_not_called_with_substring claude "plugin update laravel@laravel"
}

@test "a marketplace change outside the plugin's directory is not sent to Claude" {
    # Arrange
    given_marketplace_with_change_outside_plugin
    given_fake_claude_reviewing "VERDICT: OK"

    # Act
    run call_review_plugin_update <<< "n"

    # Assert
    assert_success
    assert_output_contains "The plugin's own files are unchanged"
    assert_binary_not_called_with_substring claude "-p "
}

@test "a failed assessment is reported and the question is still asked" {
    # Arrange
    given_marketplace_with_plugin_change
    given_fake_claude_failing_review

    # Act
    run call_review_plugin_update <<< "y"

    # Assert
    assert_success
    assert_output_contains "WARN: Claude could not assess laravel@laravel"
    assert_binary_called_with claude "plugin update laravel@laravel"
}

@test "an update that lands on a newer commit than the reviewed one is reported" {
    # Arrange
    given_marketplace_with_plugin_change
    given_fake_claude_reviewing "VERDICT: OK"
    given_plugin_update_installs_commit "$(printf '%040d' 1)"

    # Act
    run call_review_plugin_update <<< "y"

    # Assert
    assert_success
    assert_output_contains "WARN: laravel@laravel is now at 0000000, not the reviewed ${upstream_commit:0:7}"
    assert_output_does_not_contain "SUCCESS: laravel@laravel updated"
}
