#!/usr/bin/env bats

load ../../support/quality_gate

setup() {
    new_quality_fixture
}

teardown() {
    teardown_quality_fixture
}

@test "the final check is connected to Stop events with enough time to finish" {
    # Arrange
    expected_timeout=120

    # Act
    run check_stop_hook_is_configured "$expected_timeout"

    # Assert
    assert_success
}

@test "a final check runs all available project checks" {
    # Arrange
    given_dirty_project_after_php_edit_with_tools composer pint phpstan rector pest phpunit

    # Act
    run stop_event false

    # Assert
    assert_success
    assert_tool_ran pint
    assert_tool_ran phpstan
    assert_tool_ran rector
    assert_tool_ran composer
    assert_tool_ran pest
}

@test "a successful final check clears the dirty project" {
    # Arrange
    given_dirty_project_after_php_edit_with_tools composer pint phpstan rector pest phpunit

    # Act
    run stop_event false

    # Assert
    assert_success
    assert_path_does_not_exist "$marker"
}

@test "a final check can skip tests without skipping code checks" {
    # Arrange
    given_dirty_project_after_php_edit_with_tools composer pint phpstan rector pest phpunit

    # Act
    CLAUDE_QUALITY_SKIP_TESTS=1 run stop_event false

    # Assert
    assert_success
    assert_tool_ran pint
    assert_tool_ran rector
    assert_tool_did_not_run pest
}

@test "a final check can skip Rector without skipping the other checks" {
    # Arrange
    given_dirty_project_after_php_edit_with_tools composer pint phpstan rector pest phpunit

    # Act
    CLAUDE_QUALITY_SKIP_RECTOR=1 run stop_event false

    # Assert
    assert_success
    assert_tool_ran pint
    assert_tool_did_not_run rector
    assert_tool_ran pest
}

@test "a failed final check blocks the response" {
    # Arrange
    given_dirty_project_after_php_edit_with_tools composer pint phpstan rector pest phpunit
    failing_tool=phpstan

    # Act
    QUALITY_FAIL_TOOL="$failing_tool" run stop_event false

    # Assert
    assert_status 2
}

@test "a failed final check keeps the project dirty" {
    # Arrange
    given_dirty_project_after_php_edit_with_tools composer pint phpstan rector pest phpunit
    failing_tool=phpstan

    # Act
    QUALITY_FAIL_TOOL="$failing_tool" run stop_event false

    # Assert
    assert_status 2
    assert_path_exists "$marker"
}

@test "one failed project check does not prevent the remaining checks" {
    # Arrange
    given_dirty_project_after_php_edit_with_tools composer pint phpstan rector pest phpunit
    failing_tool=phpstan

    # Act
    QUALITY_FAIL_TOOL="$failing_tool" run stop_event false

    # Assert
    assert_status 2
    assert_tool_ran pint
    assert_tool_ran rector
    assert_tool_ran composer
    assert_tool_ran pest
}

@test "a repeated final check still blocks while the project is broken" {
    # Arrange
    given_dirty_project_after_php_edit_with_tools composer pint phpstan rector pest phpunit
    failing_tool=phpstan

    # Act
    QUALITY_FAIL_TOOL="$failing_tool" run stop_event true

    # Assert
    assert_status 2
    assert_tool_ran phpstan
}

@test "a repeated final check succeeds after the project is fixed" {
    # Arrange
    given_dirty_project_after_php_edit_with_tools composer pint phpstan rector pest phpunit

    # Act
    run stop_event true

    # Assert
    assert_success
    assert_tool_ran phpstan
    assert_path_does_not_exist "$marker"
}

@test "a final check clears passing projects and keeps failed projects dirty" {
    # Arrange
    given_dirty_project_after_php_edit_with_tools composer pint phpstan rector pest phpunit
    given_second_dirty_project_with_failing_phpstan
    : > "$log"

    # Act
    run stop_event false

    # Assert
    assert_status 2
    assert_path_does_not_exist "$marker"
    assert_path_exists "$second_marker"
}

@test "the next final check retries only projects that are still dirty" {
    # Arrange
    given_dirty_project_after_php_edit_with_tools composer pint phpstan rector pest phpunit
    given_second_dirty_project_with_failing_phpstan
    run stop_event false
    ln -sf "$fake_bin/tool" "$second_project/vendor/bin/phpstan"
    : > "$log"

    # Act
    run stop_event false

    # Assert
    assert_success
    assert_tool_run_count phpstan 1
    assert_path_does_not_exist "$second_marker"
}

@test "a dirty project without tooling does not block the response" {
    # Arrange
    given_dirty_project_after_php_edit_with_tools composer pint phpstan rector pest phpunit
    rm -f "$project/composer.json"

    # Act
    run stop_event false

    # Assert
    assert_success
}

@test "a final check without a working directory does nothing" {
    # Arrange
    given_dirty_project_after_php_edit_with_tools composer pint phpstan rector pest phpunit
    stop_event_without_working_directory='{}'

    # Act
    run stop_event_json "$stop_event_without_working_directory"

    # Assert
    assert_success
    assert_file_is_empty "$log"
}

@test "a final check outside a Git repository does nothing" {
    # Arrange
    given_dirty_project_after_php_edit_with_tools composer pint phpstan rector pest phpunit
    non_git_dir="$fixture/not-a-repo"
    mkdir -p "$non_git_dir"

    # Act
    run stop_event_json "$(jq -nc --arg cwd "$non_git_dir" '{cwd: $cwd}')"

    # Assert
    assert_success
    assert_file_is_empty "$log"
}

@test "a final check with no dirty projects does nothing" {
    # Arrange
    given_dirty_project_after_php_edit_with_tools composer pint phpstan rector pest phpunit
    rm -f "$marker"

    # Act
    run stop_event false

    # Assert
    assert_success
    assert_file_is_empty "$log"
}

@test "a final check ignores dirty projects from another repository" {
    # Arrange
    given_dirty_project_after_php_edit_with_tools composer pint phpstan rector pest phpunit
    other_repo="$fixture/other-repo"
    other_project="$other_repo"
    mkdir -p "$other_project/src" "$other_project/vendor/bin"
    git init -q "$other_repo"
    printf '{}\n' > "$other_project/composer.json"
    printf '<?php\n' > "$other_project/src/Example.php"
    install_tool "$other_project" pint

    other_marker="$config_home/claude-quality/runs$other_project.dirty"
    post_event post-php-edit.sh "$other_project/src/Example.php"
    assert_path_exists "$other_marker"

    : > "$log"

    # Act
    run stop_event false

    # Assert
    assert_success
    assert_path_does_not_exist "$marker"
    assert_path_exists "$other_marker"
    assert_tool_run_count pint 1
}
