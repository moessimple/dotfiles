#!/usr/bin/env bats

load ../support/test_helper
load ../support/gswitch_helper

setup() {
    new_git_function_fixture
    git -C "$repository" config checkout.defaultRemote no-such-remote
}

teardown() {
    teardown_dotfiles_fixture
}

@test "help describes gswitch without changing the repository" {
    make_repository_dirty

    run call_gswitch --help

    assert_success
    assert_output_contains "Usage: gswitch <branch>"
    assert_current_branch feature
    assert_local_changes_are_present
    assert_stash_is_empty
}

@test "a branch name is required" {
    run call_gswitch

    assert_failure
    assert_output_contains "No branch name given."
    assert_current_branch feature
}

@test "more than one branch name is rejected" {
    run call_gswitch main another-branch

    assert_failure
    assert_output_contains "Expected exactly one branch name."
    assert_current_branch feature
}

@test "gswitch selects an existing branch" {
    run call_gswitch main

    assert_success
    assert_current_branch main
    assert_stash_is_empty
}

@test "gswitch creates a branch that does not exist" {
    run call_gswitch new-branch

    assert_success
    assert_current_branch new-branch
    assert_stash_is_empty
}

@test "gswitch tracks a branch that exists on one remote" {
    create_remote_branch origin remote-branch

    run call_gswitch remote-branch

    assert_success
    assert_current_branch remote-branch
    assert_branch_tracks origin/remote-branch
}

@test "gswitch carries local changes to the selected branch" {
    make_repository_dirty

    run call_gswitch main

    assert_success
    assert_current_branch main
    assert_local_changes_are_present
    assert_stash_is_empty
}

@test "staged and unstaged changes keep their state after switching" {
    stage_then_edit_tracked_file

    run call_gswitch main

    assert_success
    assert_current_branch main
    assert_staged_file_contains tracked.txt "staged change"
    assert_worktree_file_contains tracked.txt $'staged change\nunstaged change'
    assert_stash_is_empty
}

@test "a conflict while carrying changes is reported and preserved" {
    create_conflicting_change_on_main

    run call_gswitch main

    assert_failure
    assert_current_branch main
    assert_file_has_merge_conflict tracked.txt
    assert_stash_contains "local change"
}

@test "an invalid branch name leaves local changes in the worktree" {
    make_repository_dirty

    run call_gswitch "invalid branch"

    assert_failure
    assert_output_contains "Invalid branch name: invalid branch"
    assert_current_branch feature
    assert_local_changes_are_present
    assert_stash_is_empty
}

@test "a branch that cannot be created leaves local changes in the stash" {
    git -C "$repository" branch parent main
    make_repository_dirty

    run call_gswitch parent/child

    assert_failure
    assert_output_contains "Switch failed; your changes remain in the stash."
    assert_current_branch feature
    assert_worktree_is_clean
    assert_stash_contains "changed"
}

@test "ambiguous remote branches are not replaced by a new local branch" {
    create_remote_branch one shared-branch
    create_remote_branch two shared-branch
    make_repository_dirty

    run call_gswitch shared-branch

    assert_failure
    assert_output_contains "Switch failed; your changes remain in the stash."
    assert_current_branch feature
    assert_branch_does_not_exist shared-branch
    assert_worktree_is_clean
    assert_stash_contains "changed"
}

@test "an older stash remains after carrying newer local changes" {
    printf 'older change\n' > "$repository/tracked.txt"
    git -C "$repository" stash push -qm older
    make_repository_dirty

    run call_gswitch main

    assert_success
    assert_current_branch main
    assert_local_changes_are_present
    assert_stash_count 1
    assert_stash_contains "older change"
}

@test "a stash operation that saves nothing does not consume an older stash" {
    printf 'older change\n' > "$repository/tracked.txt"
    git -C "$repository" stash push -qm older
    make_repository_dirty

    run call_gswitch_with_stash_that_does_nothing main

    assert_failure
    assert_output_contains "Could not stash local changes; branch was not switched."
    assert_current_branch feature
    assert_local_changes_are_present
    assert_stash_count 1
    assert_stash_contains "older change"
}

@test "a failed stash operation does not switch branches" {
    make_repository_dirty

    run call_gswitch_with_failing_stash main

    assert_failure
    assert_output_contains "simulated stash failure"
    assert_current_branch feature
    assert_local_changes_are_present
    assert_stash_is_empty
}

@test "calling gswitch outside a Git repository fails" {
    repository="$fixture/not-a-repository"
    mkdir -p "$repository"

    run call_gswitch main

    assert_failure
    assert_output_contains "not a git repository"
}
