#!/usr/bin/env bats

load support/test_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    write_fake_binary record-arguments
}

teardown() {
    teardown_dotfiles_fixture
}

@test "argument assertions preserve empty arguments, whitespace, and literal special characters" {
    record-arguments "" "two words" $'two\nlines' '"$*\\'

    assert_binary_called_with_args record-arguments "" "two words" $'two\nlines' '"$*\\'
    run assert_binary_called_with_args record-arguments "" two words $'two\nlines' '"$*\\'
    assert_failure
}

@test "argument assertions distinguish no arguments from one empty argument" {
    record-arguments

    assert_binary_called_with_args record-arguments
    run assert_binary_called_with_args record-arguments ""
    assert_failure
}

@test "argument assertions find a complete matching call among multiple calls" {
    record-arguments first
    record-arguments "second call" ""

    assert_binary_called_with_args record-arguments "second call" ""
    run assert_binary_called_with_args record-arguments first "second call" ""
    assert_failure
}

@test "fixture cleanup restores commands needed by the test runner" {
    export PATH="$fake_bin"

    teardown_dotfiles_fixture

    [ "$PATH" = "$fixture_original_path" ]
    command -v rm
}
