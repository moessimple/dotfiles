#!/usr/bin/env bats

load ../../support/quality_gate

setup() {
    new_quality_fixture
}

teardown() {
    teardown_quality_fixture
}

@test "a failed PHP edit remains gated until a subsequent project check passes" {
    given_project_with_tools composer pint phpstan
    marker="$config_home/claude-quality/runs$project.dirty"

    QUALITY_FAIL_TOOL=pint run post_event post-edit.sh "$project/src/Example.php"

    assert_status 2
    assert_path_exists "$marker"

    QUALITY_FAIL_TOOL=phpstan run stop_event false

    assert_status 2
    assert_path_exists "$marker"

    run stop_event false

    assert_success
    assert_path_does_not_exist "$marker"
}
