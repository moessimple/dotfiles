#!/usr/bin/env bats

load ../../support/quality_gate

setup() {
    new_quality_fixture
}

teardown() {
    teardown_quality_fixture
}

@test "the PHP edit hook is connected to Write and Edit events" {
    # Arrange
    hook=post-php-edit.sh

    # Act
    run check_post_edit_hook_is_configured "$hook"

    # Assert
    assert_success
}

@test "editing a non-PHP file does not check or mark the project" {
    # Arrange
    given_project_with_tools pint rector
    marker="$config_home/claude-quality/runs$project.dirty"

    # Act
    run post_event post-php-edit.sh "$project/README.md"

    # Assert
    assert_success
    assert_file_is_empty "$log"
    assert_path_does_not_exist "$marker"
}

@test "editing a PHP file runs its immediate code checks" {
    # Arrange
    given_project_with_tools pint rector

    # Act
    run post_event post-php-edit.sh "$project/src/Example.php"

    # Assert
    assert_success
    assert_tool_ran pint
    assert_tool_ran rector
}

@test "editing a PHP file marks the project for a final check" {
    # Arrange
    given_project_with_tools pint rector
    marker="$config_home/claude-quality/runs$project.dirty"

    # Act
    run post_event post-php-edit.sh "$project/src/Example.php"

    # Assert
    assert_success
    assert_path_exists "$marker"
}

@test "disabling automatic checks leaves an edited PHP file alone" {
    # Arrange
    given_project_with_tools pint rector
    marker="$config_home/claude-quality/runs$project.dirty"

    # Act
    CLAUDE_QUALITY_DISABLE=1 run post_event post-php-edit.sh "$project/src/Example.php"

    # Assert
    assert_success
    assert_file_is_empty "$log"
    assert_path_does_not_exist "$marker"
}
