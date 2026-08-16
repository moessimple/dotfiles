#!/usr/bin/env bats

load ../../support/quality_gate

setup() {
    new_quality_fixture
}

teardown() {
    teardown_quality_fixture
}

@test "a PHP edit is checked again before the response can finish" {
    # Arrange
    given_dirty_project_after_php_edit_with_tools composer pint phpstan rector pest phpunit

    # Act
    run stop_event false

    # Assert
    assert_success
    assert_tool_ran phpstan
    assert_tool_ran composer
    assert_tool_ran pest
    assert_path_does_not_exist "$marker"
}
