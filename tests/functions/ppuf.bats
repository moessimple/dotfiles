#!/usr/bin/env bats

load ../support/test_helper
load ../support/run_until_fail_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
}

teardown() {
    teardown_dotfiles_fixture
}

@test "ppuf --help describes usage without running anything" {
    # Act
    run call_ppuf --help

    # Assert
    assert_success
    assert_output_contains "Usage: ppuf <file|directory>"
    assert_binary_not_called php
}

@test "ppuf requires a file or directory" {
    # Act
    run call_ppuf

    # Assert
    assert_failure
    assert_output_contains "file or directory required"
    assert_binary_not_called php
}

@test "ppuf reruns the given test file in parallel until it fails" {
    # Arrange
    given_php_fails_on_run 2

    # Act
    run call_ppuf "tests/Feature"

    # Assert
    assert_failure
    assert_output_contains "✅ Pass #1"
    assert_output_contains "❌ Failed after 2 run(s)"
    assert_binary_call_count php 2
    assert_binary_called_with php \
        "artisan test --parallel --passthru-php '-d' 'memory_limit=8192M' --no-coverage --stop-on-error --stop-on-failure tests/Feature"
}
