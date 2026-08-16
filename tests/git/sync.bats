#!/usr/bin/env bats

load ../support/test_helper
load ../support/sync_helper

setup() {
    new_dotfiles_fixture
}

teardown() {
    teardown_dotfiles_fixture
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
    assert_origin_main_matches_upstream
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
