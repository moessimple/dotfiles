#!/usr/bin/env bats

load ../support/test_helper
load ../support/default_branch_helper

setup() {
    new_dotfiles_fixture
}

teardown() {
    teardown_dotfiles_fixture
}

@test "resolves to the live default branch reported by origin" {
    # Arrange
    given_clean_repository_on_main
    given_branch release
    given_origin_default_branch release

    # Act
    run call_default_branch

    # Assert
    assert_success
    assert_output_equals release
}

@test "a fork clone's upstream default branch outranks origin's" {
    # Arrange
    given_clean_repository_on_main
    given_branch release
    given_origin_default_branch main
    given_upstream_default_branch release

    # Act
    run call_default_branch

    # Assert
    assert_success
    assert_output_equals release
}

@test "falls back to the local remote-tracking HEAD when the remote is unreachable" {
    # Arrange
    given_clean_repository_on_main
    given_unreachable_origin_remote
    given_cached_origin_default_branch release

    # Act
    run call_default_branch

    # Assert
    assert_success
    assert_output_equals release
}

@test "falls back to a local main probe when the repository has no remote" {
    # Arrange
    given_repository_on_feature_branch

    # Act
    run call_default_branch

    # Assert
    assert_success
    assert_output_equals main
}

@test "exits non-zero and prints nothing when nothing resolves" {
    # Arrange
    given_clean_repository_on_main
    given_no_main_or_master_branch

    # Act
    run call_default_branch

    # Assert
    assert_failure
    assert_output_equals ""
}
