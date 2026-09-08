#!/usr/bin/env bats

load ../../../support/sync_skeleton_helper

setup() {
    new_sync_skeleton_fixture
}

teardown() {
    teardown_sync_skeleton_fixture
}

@test "a clean descendant of the starter kit passes" {
    # Arrange
    given_kit_descendant_project

    # Act
    run_preflight

    # Assert
    assert_success
    assert_output_contains "preflight: OK"
}

@test "a path outside any git repo fails with exit 1" {
    # Arrange
    given_non_git_dir

    # Act
    run_preflight

    # Assert
    assert_status 1
    assert_output_contains "not a git repository"
}

@test "an uncommitted change fails with exit 2 and lists the change on stderr" {
    # Arrange
    given_kit_descendant_project
    given_dirty_tree

    # Act
    run_preflight_stderr

    # Assert
    assert_status 2
    assert_output_contains "boost.json"
}

@test "a git repo that is not a descendant of the starter kit fails with exit 3" {
    # Arrange
    given_project_without_kit_markers

    # Act
    run_preflight

    # Assert
    assert_status 3
    assert_output_contains "does not look like a descendant"
}
