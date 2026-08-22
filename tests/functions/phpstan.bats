#!/usr/bin/env bats

load ../support/test_helper
load ../support/phpstan_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    write_fake_binary php
}

teardown() {
    teardown_dotfiles_fixture
}

@test "phpstan analyzes the given paths with verbose output and an increased memory limit" {
    # Act
    run call_phpstan "app" "config"

    # Assert
    assert_success
    assert_binary_called_with php "-d memory_limit=4096M ./vendor/bin/phpstan -vvv app config"
}
