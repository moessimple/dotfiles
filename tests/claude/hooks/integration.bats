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

    # The check after the edit fails: the edit is reported and the project is marked dirty.
    QUALITY_FAIL_TOOL=pint run post_event post-edit.sh "$project/src/Example.php"
    assert_status 2
    assert_path_exists "$marker"

    # The final check before the response fails too: the response is blocked and stays dirty.
    QUALITY_FAIL_TOOL=phpstan run stop_event false
    assert_status 2
    assert_path_exists "$marker"

    # The next final check passes: the response may finish and the project is clean.
    run stop_event false
    assert_success
    assert_path_does_not_exist "$marker"
}
