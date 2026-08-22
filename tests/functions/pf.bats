#!/usr/bin/env bats

load ../support/test_helper
load ../support/php_runner_helper

setup() {
    new_dotfiles_fixture
    working_directory="$fixture/project"
    mkdir -p "$working_directory"
    given_fake_bin_on_path
    write_fake_binary php
}

teardown() {
    teardown_dotfiles_fixture
}

@test "pf --help describes usage without running anything" {
    # Act
    run call_pf --help

    # Assert
    assert_success
    assert_output_contains "Usage: pf <filter>"
    assert_binary_not_called php
}

@test "pf filters Pest tests by name when Pest is installed" {
    # Arrange
    given_pest_installed

    # Act
    run call_pf "it computes the total"

    # Assert
    assert_success
    assert_binary_called_with php "-d memory_limit=8192M ./vendor/bin/pest --testdox --filter it computes the total"
}

@test "pf filters PHPUnit tests by name when Pest is not installed" {
    # Arrange
    given_pest_not_installed

    # Act
    run call_pf "it computes the total"

    # Assert
    assert_success
    assert_binary_called_with php "-d memory_limit=8192M ./vendor/bin/phpunit --testdox --filter it computes the total"
}
