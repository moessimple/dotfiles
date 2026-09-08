#!/usr/bin/env bats

load ../../../support/sync_skeleton_helper

setup() {
    new_sync_skeleton_fixture
}

teardown() {
    teardown_sync_skeleton_fixture
}

@test "reuses the local ~/Code clone and only fetches it" {
    # Arrange
    given_kit_remote
    given_local_kit_clone
    head_before="$(kit_clone_head)"
    given_kit_remote_advanced

    # Act
    run_fetch_kit

    # Assert
    assert_success
    split_fetch_kit_result
    [ "$fk_dir" = "$local_kit_clone" ]
    [ "$fk_branch" = "main" ]
    # The new upstream commit is now visible as origin/main...
    [ "$(git -C "$local_kit_clone" rev-parse origin/main)" != "$head_before" ]
    # ...but the working tree was never moved off the old commit.
    [ "$(kit_clone_head)" = "$head_before" ]
}

@test "resolves the default branch from the clone's origin HEAD" {
    # Arrange
    given_kit_remote master
    given_local_kit_clone

    # Act
    run_fetch_kit

    # Assert
    assert_success
    split_fetch_kit_result
    [ "$fk_branch" = "master" ]
}

@test "clones fresh when the local ~/Code checkout is a different repo" {
    # Arrange
    given_kit_remote
    given_local_clone_with_unrelated_origin
    head_before="$(kit_clone_head)"

    # Act
    run_fetch_kit

    # Assert
    assert_success
    split_fetch_kit_result
    [ "$fk_dir" != "$local_kit_clone" ]
    [ "$fk_branch" = "main" ]
    assert_file_content "$fk_dir/README.md" "kit"
    # The unrelated ~/Code checkout was left untouched.
    [ "$(kit_clone_head)" = "$head_before" ]
}

@test "prints a tab-separated dir, branch, and 40-char sha" {
    # Arrange
    given_kit_remote
    given_local_kit_clone

    # Act
    run_fetch_kit

    # Assert
    assert_success
    split_fetch_kit_result
    [ -d "$fk_dir/.git" ]
    [ "$fk_branch" = "main" ]
    [[ "$fk_sha" =~ ^[0-9a-f]{40}$ ]] || false
}
