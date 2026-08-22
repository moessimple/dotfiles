#!/usr/bin/env bats

load ../support/test_helper
load ../support/rector_helper

setup() {
    new_dotfiles_fixture
    working_directory="$fixture/project"
    mkdir -p "$working_directory"
    given_fake_bin_on_path
    write_fake_binary php
    write_fake_binary rector
}

teardown() {
    teardown_dotfiles_fixture
}

@test "rector runs the local vendor binary through php when it is installed" {
    # Arrange
    given_rector_installed_locally

    # Act
    run call_rector "--dry-run"

    # Assert
    assert_success
    assert_binary_called_with php "./vendor/bin/rector --dry-run"
    assert_binary_not_called rector
}

@test "rector falls back to the global rector command when no local binary exists" {
    # Act
    run call_rector "--dry-run"

    # Assert
    assert_success
    assert_binary_called_with rector "--dry-run"
    assert_binary_not_called php
}
