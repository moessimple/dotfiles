#!/usr/bin/env bats

load ../support/test_helper
load ../support/branches_helper
load ../support/push_helper

setup() {
    new_dotfiles_fixture
}

teardown() {
    teardown_dotfiles_fixture
}

@test "help describes branches without listing anything" {
    # Arrange
    given_clean_repository_on_main

    # Act
    run call_branches --help

    # Assert
    assert_success
    assert_output_contains "Usage: branches"
}

@test "the current branch is marked with an asterisk" {
    # Arrange
    given_repository_on_feature_branch

    # Act
    run call_branches

    # Assert
    assert_success
    assert_colorless_output_contains "* feature"
    assert_colorless_output_contains "  main"
}

@test "a branch tracking a remote shows its upstream" {
    # Arrange
    given_repository_with_origin
    call_push

    # Act
    run call_branches

    # Assert
    assert_success
    assert_colorless_output_contains "feature"
    assert_colorless_output_contains "origin/feature"
}

@test "a branch without a remote shows no upstream arrow" {
    # Arrange
    given_repository_on_feature_branch

    # Act
    run call_branches

    # Assert
    assert_success
    assert_colorless_output_does_not_contain "main  →"
}

@test "a rebased branch is listed by its latest commit, not its original authorship" {
    # Arrange
    given_clean_repository_on_main
    given_branch_with_commit_dates untouched "2001-01-01T00:00:00" "2001-01-01T00:00:00"
    given_branch_with_commit_dates rebased "2000-01-01T00:00:00" "2002-01-01T00:00:00"

    # Act
    run call_branches

    # Assert
    assert_success
    assert_branch_listed_before rebased untouched
}
