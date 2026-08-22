#!/usr/bin/env bats

load ../support/test_helper
load ../support/o_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    write_fake_binary open
}

teardown() {
    teardown_dotfiles_fixture
}

@test "o opens the current directory when no path is given" {
    # Act
    run call_o

    # Assert
    assert_success
    assert_binary_called_with open "."
}

@test "o opens a given path" {
    # Act
    run call_o "Downloads"

    # Assert
    assert_success
    assert_binary_called_with open "Downloads"
}
