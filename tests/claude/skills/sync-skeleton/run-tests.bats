#!/usr/bin/env bats

load ../../../support/sync_skeleton_helper

setup() {
    new_sync_skeleton_fixture
    given_plain_project
    given_fake_bin_on_path
    printf '{\n    "scripts": {\n        "test": "pest"\n    }\n}\n' > "$target/composer.json"
    baseline="$fixture/baseline"
}

teardown() {
    teardown_sync_skeleton_fixture
}

@test "records a passing baseline from the discovered composer test" {
    # Arrange
    write_fake_binary composer "exit 0"

    # Act
    run_run_tests "$target" --baseline "$baseline"

    # Assert
    assert_success
    run cat "$baseline"
    assert_output_contains "pass"$'\t'"composer test"
}

@test "run mode exits 1 when the test command fails" {
    # Arrange
    write_fake_binary composer "exit 1"

    # Act
    run_run_tests "$target"

    # Assert
    assert_status 1
    assert_output_contains "fail"$'\t'"composer test"
}

@test "compare flags a command that passed in the baseline and fails now" {
    # Arrange
    write_fake_binary composer "exit 0"
    run_run_tests "$target" --baseline "$baseline"
    write_fake_binary composer "exit 1"

    # Act
    run_run_tests "$target" --compare "$baseline"

    # Assert
    assert_status 1
    assert_output_contains "REGRESSION"
}

@test "compare stays green when a pre-existing failure is still failing" {
    # Arrange
    write_fake_binary composer "exit 1"
    run_run_tests "$target" --baseline "$baseline"

    # Act
    run_run_tests "$target" --compare "$baseline"

    # Assert
    assert_success
}

@test "no discoverable test command is skip, not fail" {
    # Arrange
    rm -f "$target/composer.json"

    # Act
    run_run_tests "$target"

    # Assert
    assert_success
    assert_output_contains "skip"
}
