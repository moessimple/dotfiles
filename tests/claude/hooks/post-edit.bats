#!/usr/bin/env bats

load ../../support/quality_gate

setup() {
    new_quality_fixture
}

teardown() {
    teardown_quality_fixture
}

@test "the edit hook is connected to Write and Edit events" {
    # Arrange
    hook=post-edit.sh

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
    run post_event post-edit.sh "$project/README.md"

    # Assert
    assert_success
    assert_file_is_empty "$log"
    assert_path_does_not_exist "$marker"
}

@test "editing a PHP file runs its immediate code checks" {
    # Arrange
    given_project_with_tools pint rector

    # Act
    run post_event post-edit.sh "$project/src/Example.php"

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
    run post_event post-edit.sh "$project/src/Example.php"

    # Assert
    assert_success
    assert_path_exists "$marker"
}

@test "a failing check on an edited PHP file is reported back and still marks the project" {
    # Arrange
    given_project_with_tools pint rector
    marker="$config_home/claude-quality/runs$project.dirty"

    # Act
    QUALITY_FAIL_TOOL=pint run post_event post-edit.sh "$project/src/Example.php"

    # Assert
    assert_status 2
    assert_output_contains "The file gate failed for $project/src/Example.php"
    assert_path_exists "$marker"
}

@test "editing a PHP file in a nested project marks that nested project, not the Git root" {
    # Arrange
    given_nested_project_with_tools pint rector
    nested_marker="$config_home/claude-quality/runs$project.dirty"
    root_marker="$config_home/claude-quality/runs$git_root.dirty"

    # Act
    run post_event post-edit.sh "$project/src/Example.php"

    # Assert
    assert_success
    assert_path_exists "$nested_marker"
    assert_path_does_not_exist "$root_marker"
}

@test "disabling automatic checks leaves an edited PHP file alone" {
    # Arrange
    given_project_with_tools pint rector
    marker="$config_home/claude-quality/runs$project.dirty"

    # Act
    CLAUDE_QUALITY_DISABLE=1 run post_event post-edit.sh "$project/src/Example.php"

    # Assert
    assert_success
    assert_file_is_empty "$log"
    assert_path_does_not_exist "$marker"
}

@test "editing composer.json validates it" {
    # Arrange
    given_project_with_tools composer

    # Act
    run post_event post-edit.sh "$project/composer.json"

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
    run post_event post-edit.sh "$project/composer.json"

    # Assert
    assert_success
    assert_path_exists "$marker"
}

@test "editing a composer.json nested below the repository root marks that nested project" {
    # Arrange
    given_project_with_tools composer
    nested_manifest="$project/packages/example/composer.json"
    mkdir -p "$(dirname -- "$nested_manifest")"
    printf '{}\n' > "$nested_manifest"
    nested_marker="$config_home/claude-quality/runs$project/packages/example.dirty"
    root_marker="$config_home/claude-quality/runs$project.dirty"

    # Act
    run post_event post-edit.sh "$nested_manifest"

    # Assert
    assert_success
    assert_tool_ran composer
    assert_path_exists "$nested_marker"
    assert_path_does_not_exist "$root_marker"
}
