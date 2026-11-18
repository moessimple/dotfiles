#!/usr/bin/env bats

load ../support/test_helper
load ../support/nah_helper

setup() {
    new_dotfiles_fixture
}

teardown() {
    teardown_dotfiles_fixture
}

@test "help describes nah without changing the repository" {
    # Arrange
    given_clean_repository_on_main
    given_tracked_and_untracked_changes

    # Act
    run call_nah --help

    # Assert
    assert_success
    assert_output_contains "Usage: nah"
    assert_worktree_is_dirty
}

@test "nah aborts an in-progress merge and discards the conflict" {
    # Arrange
    given_clean_repository_on_main
    given_conflicting_merge_in_progress

    # Act
    run call_nah

    # Assert
    assert_success
    assert_no_merge_in_progress
    assert_worktree_is_clean
}

@test "nah aborts an in-progress rebase and discards the conflict" {
    # Arrange
    given_clean_repository_on_main
    given_conflicting_rebase_in_progress

    # Act
    run call_nah

    # Assert
    assert_success
    assert_no_rebase_in_progress
    assert_worktree_is_clean
}

@test "nah resets tracked changes and removes untracked files" {
    # Arrange
    given_clean_repository_on_main
    given_tracked_and_untracked_changes

    # Act
    run call_nah

    # Assert
    assert_success
    assert_worktree_is_clean
    assert_path_does_not_exist "$repository/untracked.txt"
}

@test "nah run from a subdirectory also removes untracked files outside it" {
    # Arrange
    given_clean_repository_on_main
    mkdir "$repository/subdirectory"
    printf 'untracked\n' >"$repository/top-level-untracked.txt"
    printf 'untracked\n' >"$repository/subdirectory/untracked.txt"

    # Act
    run call_nah_in subdirectory

    # Assert
    assert_success
    assert_path_does_not_exist "$repository/top-level-untracked.txt"
    assert_path_does_not_exist "$repository/subdirectory/untracked.txt"
}

@test "nah aborts an in-progress cherry-pick and discards the conflict" {
    # Arrange
    given_clean_repository_on_main
    given_conflicting_cherry_pick_in_progress

    # Act
    run call_nah

    # Assert
    assert_success
    assert_no_cherry_pick_in_progress
    assert_worktree_is_clean
}

@test "nah aborts an in-progress revert and discards the conflict" {
    # Arrange
    given_clean_repository_on_main
    given_conflicting_revert_in_progress

    # Act
    run call_nah

    # Assert
    assert_success
    assert_no_revert_in_progress
    assert_worktree_is_clean
}

@test "nah aborts an in-progress bisect session and discards it" {
    # Arrange
    given_clean_repository_on_main
    given_bisect_in_progress

    # Act
    run call_nah

    # Assert
    assert_success
    assert_no_bisect_in_progress
    assert_current_branch main
    assert_worktree_is_clean
}

@test "nah on an already clean repository succeeds" {
    # Arrange
    given_clean_repository_on_main

    # Act
    run call_nah

    # Assert
    assert_success
    assert_worktree_is_clean
}

@test "nah outside a repository stops after resolving the Git directory fails" {
    repository="$fixture/outside"
    mkdir -p "$repository"
    export REAL_GIT
    REAL_GIT=$(command -v git)
    given_fake_bin_on_path
    write_fake_binary git 'exec "$REAL_GIT" "$@"'

    run call_nah

    assert_failure
    assert_binary_called_with git "rev-parse --git-dir"
    assert_binary_call_count git 1
}
