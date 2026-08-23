#!/usr/bin/env bats

load ../support/test_helper
load ../support/update_helper
load ../support/setup_cleanup_helper

setup() {
    new_dotfiles_fixture
    test_home="$fixture/home"
    repository="$test_home/.dotfiles"
    bin_dir="$fixture/bin"
    fake_bin="$bin_dir"
    mkdir -p "$repository" "$bin_dir"
    export REAL_GIT="$(command -v git)"
    export UPDATE_SIDE_EFFECT_REACHED="$fixture/update-side-effect-reached"
    export PATH="$bin_dir:$PATH"
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
    printf 'changed\n' > "$repository/tracked.txt"
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

    # Assert: the run succeeds, and each of the four custom cleanup functions was actually
    # reached, not just individually correct in isolation.
    assert_success
    assert_output_contains "Update complete!"
    assert_output_contains "No undeclared global Composer packages found"
    assert_output_contains "No undeclared global npm packages found"
    assert_output_contains "No undeclared Claude Code skills found"
    assert_output_contains "No undeclared Claude Code plugins or MCP servers found"
}
