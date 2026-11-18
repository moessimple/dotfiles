#!/usr/bin/env bats

load ../support/test_helper
load ../support/update_helper
load ../support/setup_cleanup_helper
load ../support/update_cooldown_helper

setup() {
    new_dotfiles_fixture
    test_home="$fixture/home"
    repository="$test_home/.dotfiles"
    mkdir -p "$repository"
    given_fake_bin_on_path
    export REAL_GIT="$(command -v git)"
    export UPDATE_SIDE_EFFECT_REACHED="$fixture/update-side-effect-reached"
}

teardown() {
    teardown_dotfiles_fixture
}

@test "a feature branch is rejected before the repository or packages are updated" {
    # Arrange
    given_clean_repository_on_main
    git -C "$repository" switch -qc feature
    write_update_side_effects_that_must_not_run

    # Act
    run call_update

    # Assert
    assert_failure
    assert_output_contains "is on 'feature'. Check out main"
    assert_current_branch feature
    assert_update_side_effect_was_not_reached
}

@test "detached HEAD is rejected before the repository or packages are updated" {
    # Arrange
    given_clean_repository_on_main
    git -C "$repository" switch -q --detach HEAD
    write_update_side_effects_that_must_not_run

    # Act
    run call_update

    # Assert
    assert_failure
    assert_output_contains "is in detached HEAD state. Check out main"
    assert_head_is_detached
    assert_update_side_effect_was_not_reached
}

@test "a dirty main worktree is still rejected before the repository or packages are updated" {
    # Arrange
    given_clean_repository_on_main
    printf 'changed\n' >"$repository/tracked.txt"
    write_update_side_effects_that_must_not_run

    # Act
    run call_update

    # Assert
    assert_failure
    assert_output_contains "has uncommitted changes"
    assert_current_branch main
    assert_worktree_is_dirty
    assert_update_side_effect_was_not_reached
}

@test "a full run against a clean main pulls, updates every package source, and cleans up each one" {
    # Arrange
    given_clean_repository_on_main
    given_repository_with_real_setup_scripts
    given_bare_origin_remote
    git -C "$repository" push -q origin main
    given_every_external_tool_update_touches_is_faked

    # Act
    run call_update

    # Assert: the run succeeds, and each of the six custom cleanup functions was actually
    # reached, not just individually correct in isolation.
    assert_success
    assert_output_contains "Update complete!"
    assert_file_exists "$test_home/reconfigured"
    [[ "$output" == *"Configuration applied"*"Update complete!"* ]]
    assert_output_contains "No undeclared global Composer packages found"
    assert_output_contains "No undeclared global npm packages found"
    assert_output_contains "No undeclared Python packages found"
    assert_output_contains "No undeclared Claude Code skills found"
    assert_output_contains "No undeclared Claude Code plugins or MCP servers found"
    assert_output_contains "No undeclared Ollama models found"
}

@test "the pulled version of update.sh runs the rest of the update, and the pull happens only once" {
    # Arrange
    given_clean_repository_on_main
    given_repository_with_real_setup_scripts
    given_bare_origin_remote
    git -C "$repository" push -q origin main
    given_origin_changes_update_script_to_print "pulled update.sh is running"
    given_every_external_tool_update_touches_is_faked

    # Act
    run call_update

    # Assert
    assert_success
    assert_output_contains_before "Dotfiles updated" "pulled update.sh is running"
    assert_output_contains_exactly_once "Pulling latest changes"
    assert_output_contains "Update complete!"
}

@test "a failed configuration step fails the update and is listed in its summary" {
    # Arrange
    given_clean_repository_on_main
    given_repository_with_real_setup_scripts
    printf '#!/bin/bash\nexit 17\n' >"$repository/bin/reconfigure.sh"
    git -C "$repository" commit -qam "make reconfigure fail"
    given_bare_origin_remote
    git -C "$repository" push -q origin main
    given_every_external_tool_update_touches_is_faked

    # Act
    run call_update

    # Assert
    assert_update_finished_with_problem "Could not apply the dotfiles configuration"
}

@test "Clarity is trimmed again after the skills are installed or updated" {
    # Arrange
    given_clean_repository_on_main
    given_repository_with_real_setup_scripts
    given_bare_origin_remote
    git -C "$repository" push -q origin main
    given_every_external_tool_update_touches_is_faked
    given_skills_update_restoring_clarity_extras

    # Act
    run call_update

    # Assert
    assert_success
    assert_clarity_keeps_only_its_runtime_files
}

@test "a skill change unchanged for 3 days is updated through the pinned skills CLI with a release-age cooldown" {
    # Arrange
    given_clean_repository_on_main
    given_repository_with_real_setup_scripts
    given_pinned_version support/setup/claude/claude-skills.sh SKILLS_CLI_VERSION 1.7.6
    given_bare_origin_remote
    git -C "$repository" push -q origin main
    given_every_external_tool_update_touches_is_faked
    given_skill_repository pdf https://github.com/anthropics/skills.git
    given_skill_upstream_change_to skills/pdf/SKILL.md
    given_update_ran_days_ago 3

    # Act
    run call_update

    # Assert
    assert_success
    assert_binary_called_with_substring npx "--min-release-age=3 --yes skills@1.7.6 update pdf -g"
}

@test "a pinned npm package is raised to the newest release that is at least 3 days old" {
    # Arrange
    given_clean_repository_on_main
    given_repository_with_real_setup_scripts
    given_pinned_version support/setup/claude/claude-plugins.sh CHROME_DEVTOOLS_MCP_VERSION 1.12.0
    given_bare_origin_remote
    git -C "$repository" push -q origin main
    given_every_external_tool_update_touches_is_faked
    given_npm_releases chrome-devtools-mcp 1.12.0:30 1.13.0:10 1.13.1:4 1.14.0-beta.1:4 1.14.0:2

    # Act
    run call_update

    # Assert
    assert_success
    assert_pinned_version support/setup/claude/claude-plugins.sh CHROME_DEVTOOLS_MCP_VERSION 1.13.1
    assert_output_contains "Raised chrome-devtools-mcp from 1.12.0 to 1.13.1"
}

@test "a pinned npm package stays put while the newer release is younger than 3 days" {
    # Arrange
    given_clean_repository_on_main
    given_repository_with_real_setup_scripts
    given_pinned_version support/setup/claude/claude-skills.sh SKILLS_CLI_VERSION 1.7.6
    given_bare_origin_remote
    git -C "$repository" push -q origin main
    given_every_external_tool_update_touches_is_faked
    given_npm_releases skills 1.7.6:8 1.8.0:2 1.8.1:0

    # Act
    run call_update

    # Assert
    assert_success
    assert_pinned_version support/setup/claude/claude-skills.sh SKILLS_CLI_VERSION 1.7.6
    assert_output_does_not_contain "Raised skills"
}

@test "a failed release lookup is reported instead of silently keeping the pin" {
    # Arrange
    given_clean_repository_on_main
    given_repository_with_real_setup_scripts
    given_bare_origin_remote
    git -C "$repository" push -q origin main
    given_every_external_tool_update_touches_is_faked
    given_npm_release_lookup_fails

    # Act
    run call_update

    # Assert
    assert_update_finished_with_problem "Could not check chrome-devtools-mcp for a newer release"
}

@test "plugin states unchanged for 3 days are updated, official and third-party alike" {
    # Arrange
    given_clean_repository_on_main
    given_repository_with_real_setup_scripts
    given_bare_origin_remote
    git -C "$repository" push -q origin main
    given_every_external_tool_update_touches_is_faked
    given_laravel_marketplace
    given_official_marketplace
    given_update_ran_days_ago 3

    # Act
    run call_update

    # Assert
    assert_success
    assert_binary_called_with claude "plugin marketplace update laravel"
    assert_binary_called_with claude "plugin update laravel@laravel"
    assert_binary_called_with claude "plugin marketplace update claude-plugins-official"
    assert_binary_called_with claude "plugin update typescript-lsp@claude-plugins-official"
}

@test "plugin states seen for the first time are not updated" {
    # Arrange
    given_clean_repository_on_main
    given_repository_with_real_setup_scripts
    given_bare_origin_remote
    git -C "$repository" push -q origin main
    given_every_external_tool_update_touches_is_faked
    given_laravel_marketplace
    given_official_marketplace

    # Act
    run call_update

    # Assert
    assert_success
    assert_binary_not_called_with_substring claude "plugin update"
    assert_binary_not_called_with_substring claude "plugin marketplace update"
}

@test "a failed marketplace listing is reported and the remaining updates still run" {
    # Arrange
    given_clean_repository_on_main
    given_repository_with_real_setup_scripts
    given_bare_origin_remote
    git -C "$repository" push -q origin main
    given_every_external_tool_update_touches_is_faked
    given_marketplace_listing_fails

    # Act
    run call_update

    # Assert
    assert_update_finished_with_problem "Could not list the plugin marketplaces, plugins not updated"
    assert_output_contains "No undeclared Ollama models found"
}

@test "a failed Homebrew cleanup is reported instead of swallowed" {
    # Arrange
    given_clean_repository_on_main
    given_repository_with_real_setup_scripts
    given_bare_origin_remote
    git -C "$repository" push -q origin main
    given_every_external_tool_update_touches_is_faked
    given_homebrew_cleanup_fails

    # Act
    run call_update

    # Assert
    assert_update_finished_with_problem "Could not remove every undeclared Homebrew package"
}

@test "a failed Homebrew upgrade is reported and the remaining updates still run" {
    # Arrange
    given_clean_repository_on_main
    given_repository_with_real_setup_scripts
    given_bare_origin_remote
    git -C "$repository" push -q origin main
    given_every_external_tool_update_touches_is_faked
    given_homebrew_upgrade_fails

    # Act
    run call_update

    # Assert
    assert_update_finished_with_problem "Could not upgrade every Homebrew package"
    assert_output_contains "No undeclared global Composer packages found"
}

@test "a failed global Composer update is reported and the remaining updates still run" {
    # Arrange
    given_clean_repository_on_main
    given_repository_with_real_setup_scripts
    given_bare_origin_remote
    git -C "$repository" push -q origin main
    given_every_external_tool_update_touches_is_faked
    given_global_composer_update_fails

    # Act
    run call_update

    # Assert
    assert_update_finished_with_problem "Could not update the global Composer packages"
    assert_output_does_not_contain "Composer packages updated"
    assert_output_contains "No undeclared global npm packages found"
}
