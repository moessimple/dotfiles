#!/usr/bin/env bats

load ../support/test_helper

setup() {
    new_dotfiles_fixture
}

teardown() {
    teardown_dotfiles_fixture
}

@test "changes, timeline, changelog, and site expose the Git, Composer, and Herd shortcuts" {
    # Act
    run zsh -c 'source "$1"; alias changes timeline changelog site' zsh "$aliases_file"

    # Assert
    assert_success
    assert_output_contains "changes='git diff'"
    assert_output_contains "timeline='git log --graph"
    assert_output_contains "changelog=cchangelog"
    assert_output_contains "site='herd open'"
}

@test "shell aliases do not shadow diff, log, cc, or view" {
    # Act
    run zsh -c 'source "$1"; whence -w diff log cc view' zsh "$aliases_file"

    # Assert
    assert_success
    assert_output_does_not_contain ": alias"
}
