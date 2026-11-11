#!/usr/bin/env bats

load ../support/test_helper
load ../support/run_until_fail_helper
load ../support/php_runner_helper

setup() {
    new_dotfiles_fixture
    working_directory="$fixture/project"
    mkdir -p "$working_directory"
    given_fake_bin_on_path
}

teardown() {
    teardown_dotfiles_fixture
}

@test "puff --help describes usage without running anything" {
    # Act
    run call_puff --help

    # Assert
    assert_success
    assert_output_contains "Usage: puff <filter>"
    assert_binary_not_called php
}

@test "puff requires a test case filter" {
    # Act
    run call_puff

    # Assert
    assert_failure
    assert_output_contains "test case required"
    assert_binary_not_called php
}

@test "puff reruns the given test case sequentially until it fails" {
    # Arrange
    given_php_fails_on_run 2

    # Act
    run call_puff "it computes the total"

    # Assert
    assert_failure
    assert_output_contains "✅ Pass #1"
    assert_output_contains "❌ Failed after 2 run(s)"
    assert_binary_call_count php 2
    assert_binary_called_with php \
        "-d memory_limit=8192M ./vendor/bin/phpunit --no-coverage --stop-on-error --stop-on-failure --filter it computes the total"
}

@test "puff reruns with Pest when Pest is installed" {
    # Arrange
    given_pest_installed
    given_php_fails_on_run 1

    # Act
    run call_puff "it computes the total"

    # Assert
    assert_failure
    assert_binary_called_with php \
        "-d memory_limit=8192M ./vendor/bin/pest --no-coverage --stop-on-error --stop-on-failure --filter it computes the total"
}
