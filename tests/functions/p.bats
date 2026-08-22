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

@test "p runs Pest with testdox when Pest is installed" {
    # Arrange
    given_pest_installed

    # Act
    run call_p

    # Assert
    assert_success
    assert_binary_called_with php "-d memory_limit=8192M ./vendor/bin/pest --testdox"
}

@test "p falls back to PHPUnit with testdox when Pest is not installed" {
    # Arrange
    given_pest_not_installed

    # Act
    run call_p

    # Assert
    assert_success
    assert_binary_called_with php "-d memory_limit=8192M ./vendor/bin/phpunit --testdox"
}

@test "p forwards extra arguments to the test runner" {
    # Arrange
    given_pest_installed

    # Act
    run call_p "--group=slow"

    # Assert
    assert_success
    assert_binary_called_with php "-d memory_limit=8192M ./vendor/bin/pest --testdox --group=slow"
}
