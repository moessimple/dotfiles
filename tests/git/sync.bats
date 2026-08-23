#!/usr/bin/env bats

load ../support/test_helper
load ../support/sync_helper

setup() {
    new_dotfiles_fixture
}

teardown() {
    teardown_dotfiles_fixture
}

@test "help describes sync without syncing anything" {
    # Arrange
    given_repository_on_feature_branch

    # Act
    run call_sync --help

    # Assert
    assert_success
    assert_output_contains "Usage: sync"
}

@test "sync without an upstream remote configured fails" {
    # Arrange
    given_repository_on_feature_branch

    # Act
    run call_sync

    # Assert
    assert_failure
    assert_output_contains "No upstream remote configured"
}

@test "sync restores the starting branch and local changes after a push fails" {
    # Arrange
    given_repository_on_feature_branch
    given_upstream_main_and_unreachable_origin
    given_tracked_and_untracked_changes

    # Act
    run call_sync

    # Assert
    assert_failure
    assert_current_branch feature
    assert_file_content "$repository/tracked.txt" "changed"
    assert_file_exists "$repository/untracked.txt"
    assert_stash_is_empty
}

@test "sync updates origin main to match upstream" {
    # Arrange
    given_repository_on_feature_branch
    given_upstream_main_and_empty_origin

    # Act
    run call_sync

    # Assert
    assert_success
    assert_origin_branch_matches_upstream main
}

@test "sync creates a local branch from upstream when it does not exist locally yet" {
    # Arrange
    given_repository_on_feature_branch
    given_upstream_develop_only_and_empty_origin

    # Act
    run call_sync

    # Assert
    assert_success
    assert_branch_exists develop
    assert_origin_branch_matches_upstream develop
    assert_current_branch feature
}

@test "sync updates every long-lived branch that exists on upstream, not just the first" {
    # Arrange
    given_repository_on_feature_branch
    given_upstream_main_and_develop_and_empty_origin

    # Act
    run call_sync

    # Assert
    assert_success
    assert_origin_branch_matches_upstream main
    assert_origin_branch_matches_upstream develop
}

@test "sync restores a detached starting point to the same commit after a successful sync" {
    # Arrange
    given_repository_on_feature_branch
    given_upstream_main_and_empty_origin
    detached_commit=$(git -C "$repository" rev-parse HEAD)
    git -C "$repository" switch -q --detach

    # Act
    run call_sync

    # Assert
    assert_success
    assert_head_is_detached
    [ "$(git -C "$repository" rev-parse HEAD)" = "$detached_commit" ]
}

@test "sync reports failure but still restores the starting branch when pushing tags fails" {
    # Arrange
    given_repository_on_feature_branch
    given_upstream_main_and_empty_origin

    # Act
    run call_sync_with_failing_tag_push

    # Assert
    assert_failure
    assert_output_contains "simulated tag push failure"
    assert_current_branch feature
}

@test "sync restores the starting branch and local changes after a successful sync" {
    # Arrange
    given_repository_on_feature_branch
    given_upstream_main_and_empty_origin
    given_tracked_and_untracked_changes

    # Act
    run call_sync

    # Assert
    assert_success
    assert_current_branch feature
    assert_file_content "$repository/tracked.txt" "changed"
    assert_file_exists "$repository/untracked.txt"
    assert_stash_is_empty
}

@test "sync prunes branches after a successful sync" {
    # Arrange
    given_repository_on_feature_branch
    given_upstream_main_and_empty_origin
    prune_log="$fixture/prune.log"

    # Act
    run call_sync_with_observable_prune

    # Assert
    assert_success
    assert_file_exists "$prune_log"
}
