#!/usr/bin/env bats

load ../support/test_helper
load ../support/tinker_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    write_fake_binary php
}

teardown() {
    teardown_dotfiles_fixture
}

@test "tinker --help describes usage without starting anything" {
    # Act
    run call_tinker --help

    # Assert
    assert_success
    assert_output_contains "Usage: tinker [expression]"
    assert_binary_not_called php
}

@test "tinker opens the interactive REPL when no expression is given" {
    # Act
    run call_tinker

    # Assert
    assert_success
    assert_binary_called_with php "artisan tinker"
}

@test "tinker dumps the result of a given expression instead of opening the REPL" {
    # Act
    run call_tinker "1+1"

    # Assert
    assert_success
    assert_binary_called_with php "artisan tinker --execute=dd(1+1);"
}
