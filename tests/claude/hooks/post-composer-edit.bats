#!/usr/bin/env bats

load ../../support/quality_gate

setup() {
    new_quality_fixture
}

teardown() {
    teardown_quality_fixture
}

@test "the Composer edit hook is connected to Write and Edit events" {
    # Arrange
    hook=post-composer-edit.sh

    # Act
    run check_post_edit_hook_is_configured "$hook"

    # Assert
    assert_success
}

@test "editing composer.json validates it" {
    # Arrange
    given_project_with_tools composer

    # Act
    run post_event post-composer-edit.sh "$project/composer.json"

    # Assert
    assert_success
    assert_tool_ran composer
    assert_tool_ran_with_argument composer validate
}

@test "editing composer.json marks the project for a final check" {
    # Arrange
    given_project_with_tools composer
    marker="$config_home/claude-quality/runs$project.dirty"

    # Act
    run post_event post-composer-edit.sh "$project/composer.json"

    # Assert
    assert_success
    assert_path_exists "$marker"
}

@test "editing a composer.json outside the repository root does nothing" {
    # Arrange
    given_project_with_tools composer
    marker="$config_home/claude-quality/runs$project.dirty"
    other_manifest="$project/packages/example/composer.json"
    mkdir -p "$(dirname -- "$other_manifest")"
    printf '{}\n' > "$other_manifest"

    # Act
    run post_event post-composer-edit.sh "$other_manifest"

    # Assert
    assert_success
    assert_file_is_empty "$log"
    assert_path_does_not_exist "$marker"
}
