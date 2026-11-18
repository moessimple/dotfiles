#!/usr/bin/env bats

load test_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    write_fake_binary record-arguments
}

teardown() {
    teardown_dotfiles_fixture
}

@test "argument assertions preserve empty arguments, whitespace, and literal special characters" {
    # Arrange
    record-arguments "" "two words" $'two\nlines' '"$*\\'

    assert_binary_called_with_args record-arguments "" "two words" $'two\nlines' '"$*\\'

    # Act
    run assert_binary_called_with_args record-arguments "" two words $'two\nlines' '"$*\\'

    # Assert
    assert_failure
}

@test "argument assertions distinguish no arguments from one empty argument" {
    # Arrange
    record-arguments

    assert_binary_called_with_args record-arguments

    # Act
    run assert_binary_called_with_args record-arguments ""

    # Assert
    assert_failure
}

@test "argument assertions find a complete matching call among multiple calls" {
    # Arrange
    record-arguments first
    record-arguments "second call" ""

    assert_binary_called_with_args record-arguments "second call" ""

    # Act
    run assert_binary_called_with_args record-arguments first "second call" ""

    # Assert
    assert_failure
}

@test "fixture cleanup restores commands needed by the test runner" {
    # Arrange
    export PATH="$fake_bin"

    # Act
    teardown_dotfiles_fixture

    # Assert
    [ "$PATH" = "$fixture_original_path" ]
    command -v rm
}
