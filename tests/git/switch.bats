#!/usr/bin/env bats

load ../support/test_helper
load ../support/switch_helper

setup() {
    new_dotfiles_fixture
}

teardown() {
    teardown_dotfiles_fixture
}

@test "help describes switch without changing the repository" {
    # Arrange
    given_switch_repository_on_feature_branch
    given_tracked_and_untracked_changes

    # Act
    run call_switch --help

    # Assert
    assert_success
    assert_output_contains "Usage: switch <branch>"
    assert_current_branch feature
    assert_local_changes_are_present
    assert_stash_is_empty
}

@test "a branch name is required" {
    # Arrange
    given_switch_repository_on_feature_branch

    # Act
    run call_switch

    # Assert
    assert_failure
    assert_output_contains "No branch name given."
    assert_current_branch feature
}

@test "more than one branch name is rejected" {
    # Arrange
    given_switch_repository_on_feature_branch

    # Act
    run call_switch main another-branch

    # Assert
    assert_failure
    assert_output_contains "Expected exactly one branch name."
    assert_current_branch feature
}

@test "switch selects an existing branch" {
    # Arrange
    given_switch_repository_on_feature_branch

    # Act
    run call_switch main

    # Assert
    assert_success
    assert_current_branch main
    assert_stash_is_empty
}

@test "switch creates a branch that does not exist" {
    # Arrange
    given_switch_repository_on_feature_branch

    # Act
    run call_switch new-branch

    # Assert
    assert_success
    assert_current_branch new-branch
    assert_stash_is_empty
}

@test "switch tracks a branch that exists on one remote" {
    # Arrange
    given_switch_repository_on_feature_branch
    create_remote_branch origin remote-branch

    # Act
    run call_switch remote-branch

    # Assert
    assert_success
    assert_current_branch remote-branch
    assert_branch_tracks origin/remote-branch
}

@test "switch carries local changes to the selected branch" {
    # Arrange
    given_switch_repository_on_feature_branch
    given_tracked_and_untracked_changes

    # Act
    run call_switch main

    # Assert
    assert_success
    assert_current_branch main
    assert_local_changes_are_present
    assert_stash_is_empty
}

@test "staged and unstaged changes keep their state after switching" {
    # Arrange
    given_switch_repository_on_feature_branch
    stage_then_edit_tracked_file

    # Act
    run call_switch main

    # Assert
    assert_success
    assert_current_branch main
    assert_staged_file_contains tracked.txt "staged change"
    assert_worktree_file_contains tracked.txt $'staged change\nunstaged change'
    assert_stash_is_empty
}

@test "a conflict while carrying changes is reported and preserved" {
    # Arrange
    given_switch_repository_on_feature_branch
    create_conflicting_change_on_main

    # Act
    run call_switch main

    # Assert
    assert_failure
    assert_current_branch main
    assert_file_has_merge_conflict tracked.txt
    assert_stash_contains "local change"
}

@test "an invalid branch name leaves local changes in the worktree" {
    # Arrange
    given_switch_repository_on_feature_branch
    given_tracked_and_untracked_changes

    # Act
    run call_switch "invalid branch"

    # Assert
    assert_failure
    assert_output_contains "Invalid branch name: invalid branch"
    assert_current_branch feature
    assert_local_changes_are_present
    assert_stash_is_empty
}

@test "a branch that cannot be created leaves local changes in the stash" {
    # Arrange
    given_switch_repository_on_feature_branch
    git -C "$repository" branch parent main
    given_tracked_and_untracked_changes

    # Act
    run call_switch parent/child

    # Assert
    assert_failure
    assert_output_contains "Switch failed; your changes remain in the stash."
    assert_current_branch feature
    assert_worktree_is_clean
    assert_stash_contains "changed"
}

@test "ambiguous remote branches are not replaced by a new local branch" {
    # Arrange
    given_switch_repository_on_feature_branch
    create_remote_branch one shared-branch
    create_remote_branch two shared-branch
    given_tracked_and_untracked_changes

    # Act
    run call_switch shared-branch

    # Assert
    assert_failure
    assert_output_contains "Switch failed; your changes remain in the stash."
    assert_current_branch feature
    assert_branch_does_not_exist shared-branch
    assert_worktree_is_clean
    assert_stash_contains "changed"
}

@test "an older stash remains after carrying newer local changes" {
    # Arrange
    given_switch_repository_on_feature_branch
    printf 'older change\n' > "$repository/tracked.txt"
    git -C "$repository" stash push -qm older
    given_tracked_and_untracked_changes

    # Act
    run call_switch main

    # Assert
    assert_success
    assert_current_branch main
    assert_local_changes_are_present
    assert_stash_count 1
    assert_stash_contains "older change"
}

@test "a stash operation that saves nothing does not consume an older stash" {
    # Arrange
    given_switch_repository_on_feature_branch
    printf 'older change\n' > "$repository/tracked.txt"
    git -C "$repository" stash push -qm older
    given_tracked_and_untracked_changes

    # Act
    run call_switch_with_stash_that_does_nothing main

    # Assert
    assert_failure
    assert_output_contains "Could not stash local changes; branch was not switched."
    assert_current_branch feature
    assert_local_changes_are_present
    assert_stash_count 1
    assert_stash_contains "older change"
}

@test "a failed stash operation does not switch branches" {
    # Arrange
    given_switch_repository_on_feature_branch
    given_tracked_and_untracked_changes

    # Act
    run call_switch_with_failing_stash main

    # Assert
    assert_failure
    assert_output_contains "simulated stash failure"
    assert_current_branch feature
    assert_local_changes_are_present
    assert_stash_is_empty
}

@test "calling switch outside a Git repository fails" {
    # Arrange
    repository="$fixture/not-a-repository"
    mkdir -p "$repository"

    # Act
    run call_switch main

    # Assert
    assert_failure
    assert_output_contains "not a git repository"
}
