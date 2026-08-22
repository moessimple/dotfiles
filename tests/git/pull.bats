#!/usr/bin/env bats

load ../support/test_helper
load ../support/pull_helper

setup() {
    new_dotfiles_fixture
}

teardown() {
    teardown_dotfiles_fixture
}

@test "pulling with a detached HEAD is rejected" {
    # Arrange
    given_repository_on_feature_branch
    git -C "$repository" switch -q --detach

    # Act
    run call_pull

    # Assert
    assert_failure
    assert_output_contains "Cannot pull while HEAD is detached."
}

@test "a successful pull restores stashed local changes" {
    # Arrange
    given_repository_on_feature_branch
    given_origin_commit_missing_from_local_branch from-origin.txt "from origin"
    given_tracked_and_untracked_changes

    # Act
    run call_pull

    # Assert
    assert_success
    assert_local_changes_are_present
    assert_stash_is_empty
}

@test "pull leaves local changes stashed when the pull fails" {
    # Arrange
    given_repository_on_feature_branch
    given_tracked_and_untracked_changes
    given_unreachable_origin_remote

    # Act
    run call_pull

    # Assert
    assert_failure
    assert_current_branch feature
    assert_worktree_is_clean
    assert_stash_count 1
    assert_output_contains "changes remain in the stash"
}

@test "pull brings remote changes into the current branch" {
    # Arrange
    given_repository_on_feature_branch
    given_origin_commit_missing_from_local_branch from-origin.txt "from origin"

    # Act
    run call_pull

    # Assert
    assert_success
    assert_file_content "$repository/from-origin.txt" "from origin"
}
