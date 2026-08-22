#!/usr/bin/env bats

load ../support/test_helper
load ../support/quality_helper

setup() {
    new_dotfiles_fixture
    given_fake_home_with_quality_gate
}

teardown() {
    teardown_dotfiles_fixture
}

@test "quality --help describes usage without running the gate" {
    # Act
    run call_quality --help

    # Assert
    assert_success
    assert_output_contains "quality [fast|full]"
    assert_quality_gate_not_called
}

@test "quality with no arguments runs the fast gate" {
    # Act
    run call_quality

    # Assert
    assert_success
    assert_quality_gate_called_with "fast"
}

@test "quality full runs the full gate" {
    # Act
    run call_quality full

    # Assert
    assert_success
    assert_quality_gate_called_with "full"
}

@test "quality file runs the single-file gate for the given path" {
    # Act
    run call_quality file "app/Models/User.php"

    # Assert
    assert_success
    assert_quality_gate_called_with "file app/Models/User.php"
}

@test "an unknown quality mode is rejected without running the gate" {
    # Act
    run call_quality bogus

    # Assert
    assert_status 64
    assert_output_contains "Unknown quality mode: bogus"
    assert_quality_gate_not_called
}

@test "quality status reports that no gate run has been recorded yet" {
    # Arrange
    given_composer_project_repository
    local resolved_repository
    resolved_repository="$(cd "$repository" && pwd -P)"

    # Act
    run call_quality_in "$repository" status

    # Assert
    assert_success
    assert_output_contains "No recorded gate run for $resolved_repository."
}
