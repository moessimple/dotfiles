#!/usr/bin/env bats

load ../support/test_helper
load ../support/merge_helper

setup() {
    new_dotfiles_fixture
}

teardown() {
    teardown_dotfiles_fixture
}

@test "merge leaves local changes stashed when the merge fails" {
    # Arrange
    given_repository_on_feature_branch
    given_tracked_and_untracked_changes

    # Act
    run call_merge missing-branch

    # Assert
    assert_failure
    assert_current_branch feature
    assert_worktree_is_clean
    assert_stash_count 1
    assert_output_contains "changes remain in the stash"
}

@test "merge brings changes from the selected branch into the current branch" {
    # Arrange
    given_repository_on_feature_branch
    git -C "$repository" switch -q main
    printf 'from main\n' > "$repository/from-main.txt"
    git -C "$repository" add from-main.txt
    git -C "$repository" commit -qm "change on main"
    git -C "$repository" switch -q feature

    # Act
    run call_merge main

    # Assert
    assert_success
    assert_file_content "$repository/from-main.txt" "from main"
}
