#!/usr/bin/env bats

load ../support/test_helper
load ../support/php_runner_helper

setup() {
    new_dotfiles_fixture
    working_directory="$fixture/project"
    mkdir -p "$working_directory"
    given_fake_bin_on_path
    write_fake_binary herd
}

teardown() {
    teardown_dotfiles_fixture
}

@test "pc runs Pest with coverage through Herd when Pest is installed" {
    # Arrange
    given_pest_installed

    # Act
    run call_pc

    # Assert
    assert_success
    assert_binary_called_with herd "coverage -d memory_limit=8192M ./vendor/bin/pest --testdox --coverage"
}

@test "pc runs PHPUnit with HTML coverage through Herd when Pest is not installed" {
    # Arrange
    given_pest_not_installed

    # Act
    run call_pc

    # Assert
    assert_success
    assert_binary_called_with herd "coverage -d memory_limit=8192M ./vendor/bin/phpunit --testdox --coverage-html build/coverage"
}
