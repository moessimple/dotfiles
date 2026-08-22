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

@test "puf --help describes usage without running anything" {
    # Act
    run call_puf --help

    # Assert
    assert_success
    assert_output_contains "Usage: puf <file|directory>"
    assert_binary_not_called php
}

@test "puf requires a file or directory" {
    # Act
    run call_puf

    # Assert
    assert_failure
    assert_output_contains "file or directory required"
    assert_binary_not_called php
}

@test "puf reruns the given test file sequentially until it fails" {
    # Arrange
    given_php_fails_on_run 3

    # Act
    run call_puf "tests/Unit/ExampleTest.php"

    # Assert
    assert_failure
    assert_output_contains "✅ Pass #1"
    assert_output_contains "✅ Pass #2"
    assert_output_contains "❌ Failed after 3 run(s)"
    assert_binary_call_count php 3
    assert_binary_called_with php \
        "-d memory_limit=8192M ./vendor/bin/phpunit --no-coverage --stop-on-error --stop-on-failure tests/Unit/ExampleTest.php"
}
