#!/usr/bin/env bats

load ../../support/test_helper
load ../../support/update_cooldown_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    test_home="$fixture/home"
    mkdir -p "$test_home/.claude/plugins"
}

teardown() {
    teardown_dotfiles_fixture
}

@test "a plugin state seen for the first time is not updated" {
    # Arrange
    given_marketplace

    # Act
    run call_update_plugins_after_cooldown

    # Assert
    assert_success
    assert_output_equals ""
    assert_binary_not_called_with_substring claude "update"
}

@test "a plugin state unchanged for 3 days is updated" {
    # Arrange
    given_marketplace
    given_plugin_state_seen_days_ago 3

    # Act
    run call_update_plugins_after_cooldown

    # Assert
    assert_success
    assert_binary_called_with claude "plugin marketplace update laravel"
    assert_binary_called_with claude "plugin update laravel@laravel"
}

@test "a plugin state seen 2 days ago is not updated yet" {
    # Arrange
    given_marketplace
    given_plugin_state_seen_days_ago 2

    # Act
    run call_update_plugins_after_cooldown

    # Assert
    assert_success
    assert_binary_not_called_with_substring claude "update"
}

@test "a change to the plugin's folder starts the cooldown again" {
    # Arrange
    given_marketplace
    given_plugin_state_seen_days_ago 3
    given_upstream_change_to laravel/hooks/hooks.json

    # Act
    run call_update_plugins_after_cooldown

    # Assert
    assert_success
    assert_binary_not_called_with_substring claude "update"
}

@test "a change to the plugin's marketplace entry starts the cooldown again" {
    # Arrange
    given_marketplace
    given_plugin_state_seen_days_ago 3
    given_upstream_marketplace_entry '{"name":"laravel","source":"./laravel","hooks":{"SessionStart":[]}}'

    # Act
    run call_update_plugins_after_cooldown

    # Assert
    assert_success
    assert_binary_not_called_with_substring claude "update"
}

@test "a change outside the plugin's folder does not start the cooldown again" {
    # Arrange
    given_marketplace
    given_plugin_state_seen_days_ago 3
    given_upstream_change_to other-plugin/README.md

    # Act
    run call_update_plugins_after_cooldown

    # Assert
    assert_success
    assert_binary_called_with claude "plugin update laravel@laravel"
}

@test "a plugin whose source names the marketplace's own repository counts every change in it" {
    # Arrange
    given_marketplace "{\"name\":\"laravel\",\"source\":{\"source\":\"url\",\"url\":\"$fixture/marketplace.git\"}}"
    given_plugin_state_seen_days_ago 3
    given_upstream_change_to other-plugin/README.md

    # Act
    run call_update_plugins_after_cooldown

    # Assert
    assert_success
    assert_binary_not_called_with_substring claude "update"
}

@test "a plugin whose source is another repository is reported and not updated" {
    # Arrange
    given_marketplace '{"name":"laravel","source":{"source":"github","repo":"someone/elsewhere"}}'
    given_plugin_state_seen_days_ago 3

    # Act
    run call_update_plugins_after_cooldown

    # Assert
    assert_success
    assert_output_contains "WARN: Could not check laravel@laravel in the laravel marketplace, not updated"
    assert_binary_not_called_with_substring claude "update"
}

@test "a plugin past its cooldown waits while another plugin of its marketplace is still in its cooldown" {
    # Arrange
    given_marketplace
    given_plugin_state_seen_days_ago 3

    # Act
    run call_update_plugins_after_cooldown "laravel@laravel" "other-plugin@laravel"

    # Assert
    assert_success
    assert_binary_not_called_with_substring claude "update"
}

@test "all plugins of a marketplace past their cooldown are updated after one refresh" {
    # Arrange
    given_marketplace
    given_plugin_states_seen_days_ago 3 "laravel@laravel" "other-plugin@laravel"

    # Act
    run call_update_plugins_after_cooldown "laravel@laravel" "other-plugin@laravel"

    # Assert
    assert_success
    assert_binary_called_with claude "plugin marketplace update laravel"
    assert_binary_called_with claude "plugin update laravel@laravel"
    assert_binary_called_with claude "plugin update other-plugin@laravel"
}

@test "a first-seen time that is not a number starts the cooldown again" {
    # Arrange
    given_marketplace
    given_plugin_state_seen_days_ago 3
    given_first_sighting_time_replaced_with "soon"

    # Act
    run call_update_plugins_after_cooldown

    # Assert
    assert_success
    assert_binary_not_called_with_substring claude "update"
}

@test "an empty marketplace repository is reported without ending the run" {
    # Arrange
    given_empty_marketplace

    # Act
    run call_update_plugins_after_cooldown

    # Assert
    assert_success
    assert_output_contains "WARN: Could not check laravel@laravel in the laravel marketplace, not updated"
}

@test "a failed marketplace listing is reported" {
    # Arrange
    write_fake_binary claude "exit 1"

    # Act
    run call_update_plugins_after_cooldown

    # Assert
    assert_success
    assert_output_contains "WARN: Could not list the plugin marketplaces, plugins not updated"
}

@test "a skill change seen for the first time is not updated" {
    # Arrange
    given_skill_repository diagnosing-bugs
    given_skill_upstream_change_to skills/diagnosing-bugs/SKILL.md

    # Act
    run call_update_skills_after_cooldown

    # Assert
    assert_success
    assert_binary_not_called_with_substring npx "update diagnosing-bugs"
}

@test "a skill change unchanged for 3 days is updated" {
    # Arrange
    given_skill_repository diagnosing-bugs
    given_skill_upstream_change_to skills/diagnosing-bugs/SKILL.md
    given_skill_state_seen_days_ago 3

    # Act
    run call_update_skills_after_cooldown

    # Assert
    assert_success
    assert_binary_called_with_substring npx "update diagnosing-bugs -g"
}

@test "an Anthropic skill waits out the same cooldown" {
    # Arrange
    given_skill_repository pdf https://github.com/anthropics/skills.git
    given_skill_upstream_change_to skills/pdf/SKILL.md

    # Act
    run call_update_skills_after_cooldown

    # Assert
    assert_success
    assert_binary_not_called_with_substring npx "update pdf"
}

@test "a skill at its installed version is not updated" {
    # Arrange
    given_skill_repository diagnosing-bugs
    given_skill_state_seen_days_ago 3

    # Act
    run call_update_skills_after_cooldown

    # Assert
    assert_success
    assert_binary_not_called_with_substring npx "update diagnosing-bugs"
}

@test "a change outside the skill's folder is not a change of the skill" {
    # Arrange
    given_skill_repository diagnosing-bugs
    given_skill_upstream_change_to docs/index.md
    given_skill_state_seen_days_ago 3

    # Act
    run call_update_skills_after_cooldown

    # Assert
    assert_success
    assert_binary_not_called_with_substring npx "update diagnosing-bugs"
}
