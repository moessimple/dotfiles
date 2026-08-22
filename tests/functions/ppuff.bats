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

@test "ppuff --help describes usage without running anything" {
    # Act
    run call_ppuff --help

    # Assert
    assert_success
    assert_output_contains "Usage: ppuff <filter>"
    assert_binary_not_called php
}

@test "ppuff requires a test case filter" {
    # Act
    run call_ppuff

    # Assert
    assert_failure
    assert_output_contains "test case required"
    assert_binary_not_called php
}

@test "ppuff reruns the given test case in parallel until it fails" {
    # Arrange
    given_php_fails_on_run 3

    # Act
    run call_ppuff "it computes the total"

    # Assert
    assert_failure
    assert_output_contains "✅ Pass #1"
    assert_output_contains "✅ Pass #2"
    assert_output_contains "❌ Failed after 3 run(s)"
    assert_binary_call_count php 3
    assert_binary_called_with php \
        "artisan test --parallel --passthru-php '-d' 'memory_limit=8192M' --no-coverage --stop-on-error --stop-on-failure --filter it computes the total"
}
