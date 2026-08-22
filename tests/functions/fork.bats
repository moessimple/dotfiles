#!/usr/bin/env bats

load ../support/test_helper
load ../support/fork_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    write_fake_binary gh
}

teardown() {
    teardown_dotfiles_fixture
}

@test "fork --help describes usage without contacting GitHub" {
    # Act
    run call_fork --help

    # Assert
    assert_success
    assert_output_contains "Usage: fork <repo>"
    assert_binary_not_called gh
}

@test "fork requires a repository" {
    # Act
    run call_fork

    # Assert
    assert_failure
    assert_output_contains "No repo was given."
    assert_binary_not_called gh
}

@test "fork switches gh to SSH and forks the given repository with a local clone" {
    # Act
    run call_fork "owner/name"

    # Assert
    assert_success
    assert_binary_called_with gh "config set -h github.com git_protocol ssh"
    assert_binary_called_with gh "repo fork owner/name --clone"
}
