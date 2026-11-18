#!/usr/bin/env bats

load ../../support/quality_gate

setup() {
    new_quality_fixture
}

teardown() {
    teardown_quality_fixture
}

@test "a PHP edit whose check fails keeps blocking responses until a later check passes" {
    # Arrange
    given_project_with_tools composer pint phpstan
    marker="$config_home/claude-quality/runs$project.dirty"

    # Act: edit a PHP file while Pint fails.
    QUALITY_FAIL_TOOL=pint run post_event post-edit.sh "$project/src/Example.php"

    # Assert: the edit is reported and the project is marked dirty.
    assert_status 2
    assert_path_exists "$marker"

    # Act: finish the response while PHPStan fails.
    QUALITY_FAIL_TOOL=phpstan run stop_event false

    # Assert: the response is blocked and the project stays dirty.
    assert_status 2
    assert_path_exists "$marker"

    # Act: finish the response with every check passing.
    run stop_event false

    # Assert: the response may finish and the project is clean.
    assert_success
    assert_path_does_not_exist "$marker"
}
