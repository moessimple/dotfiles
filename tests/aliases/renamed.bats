#!/usr/bin/env bats

load ../support/test_helper

setup() {
    new_dotfiles_fixture
}

teardown() {
    teardown_dotfiles_fixture
}

@test "the git, Composer and Herd shortcuts have names of their own" {
    # Act
    run zsh -c 'source "$1"; alias changes timeline changelog site' zsh "$aliases_file"

    # Assert
    assert_success
    assert_output_contains "changes='git diff'"
    assert_output_contains "timeline='git log --graph"
    assert_output_contains "changelog=cchangelog"
    assert_output_contains "site='herd open'"
}

@test "diff, log, cc and view are no longer aliases" {
    # Act
    run zsh -c 'source "$1"; whence -w diff log cc view' zsh "$aliases_file"

    # Assert
    assert_success
    assert_output_does_not_contain ": alias"
}
