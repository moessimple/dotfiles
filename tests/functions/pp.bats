#!/usr/bin/env bats

load ../support/test_helper
load ../support/php_runner_helper

setup() {
    new_dotfiles_fixture
    working_directory="$fixture/project"
    mkdir -p "$working_directory"
    given_fake_bin_on_path
    given_herd_forwarding_php_and_composer
    write_fake_binary php
}

teardown() {
    teardown_dotfiles_fixture
}

@test "pp runs Pest in parallel when Pest is installed" {
    # Arrange
    given_pest_installed

    # Act
    run call_pp

    # Assert
    assert_success
    assert_binary_called_with php "-d memory_limit=2G ./vendor/bin/pest --parallel"
}

@test "pp runs artisan test in parallel when Pest is not installed" {
    # Arrange
    given_pest_not_installed

    # Act
    run call_pp

    # Assert
    assert_success
    assert_binary_called_with php \
        "-d memory_limit=2G artisan test --parallel --passthru-php '-d' 'memory_limit=2G' --no-coverage"
}
