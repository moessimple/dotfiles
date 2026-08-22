#!/usr/bin/env bats

load ../support/test_helper
load ../support/prune_helper

setup() {
    new_dotfiles_fixture
}

teardown() {
    teardown_dotfiles_fixture
}

@test "help describes prune without deleting anything" {
    # Arrange
    given_repository_with_origin_on_main
    given_merged_branch_pushed_to_origin merged

    # Act
    run call_prune --help

    # Assert
    assert_success
    assert_output_contains "Usage: prune"
    assert_branch_exists merged
}

@test "a local branch merged into the default branch is deleted" {
    # Arrange
    given_repository_with_origin_on_main
    given_merged_branch_pushed_to_origin merged

    # Act
    run call_prune

    # Assert
    assert_success
    assert_branch_does_not_exist merged
}

@test "the remote counterpart of a merged branch is deleted" {
    # Arrange
    given_repository_with_origin_on_main
    given_merged_branch_pushed_to_origin merged

    # Act
    run call_prune

    # Assert
    assert_success
    assert_remote_branch_does_not_exist merged
}

@test "a local branch with an unreachable upstream is deleted" {
    # Arrange
    given_repository_with_origin_on_main
    given_branch_with_gone_upstream stale

    # Act
    run call_prune

    # Assert
    assert_success
    assert_branch_does_not_exist stale
}

@test "the default branch is never deleted" {
    # Arrange
    given_repository_with_origin_on_main

    # Act
    run call_prune

    # Assert
    assert_success
    assert_branch_exists main
}

@test "a merged branch with a protected name other than the default branch is kept" {
    # Arrange
    given_repository_with_origin_on_main
    given_merged_branch_pushed_to_origin develop

    # Act
    run call_prune

    # Assert
    assert_success
    assert_branch_exists develop
}

@test "the currently checked out branch keeps its local copy but loses its remote copy when not protected by name" {
    # Arrange
    given_repository_with_origin_on_main
    given_merged_branch_pushed_to_origin current-work
    git -C "$repository" switch -q current-work

    # Act
    run call_prune

    # Assert
    # The "*" current-branch marker that protects local branches has no equivalent in the
    # remote-tracking branch listing, so only the local copy survives.
    assert_failure
    assert_branch_exists current-work
    assert_remote_branch_does_not_exist current-work
}

@test "an unmerged branch is kept" {
    # Arrange
    given_repository_with_origin_on_main
    given_unmerged_branch_pushed_to_origin unmerged

    # Act
    run call_prune

    # Assert
    assert_success
    assert_branch_exists unmerged
}
