#!/usr/bin/env bats

load ../support/test_helper
load ../support/push_helper

setup() {
    new_dotfiles_fixture
}

teardown() {
    teardown_dotfiles_fixture
}

@test "help describes push without pushing" {
    # Arrange
    given_repository_with_origin

    # Act
    run call_push --help

    # Assert
    assert_success
    assert_output_contains "Usage: push [git push options]"
}

@test "push sends the current branch to origin and sets its upstream" {
    # Arrange
    given_repository_with_origin

    # Act
    run call_push

    # Assert
    assert_success
    assert_branch_pushed_to_origin
    assert_branch_tracks origin/feature
}

@test "extra arguments are passed through to git push" {
    # Arrange
    given_repository_with_origin

    # Act
    run call_push --dry-run

    # Assert
    assert_success
    assert_output_contains "[new branch]"
    assert_remote_branch_does_not_exist feature
}

@test "pushing without a reachable origin fails" {
    # Arrange
    given_repository_on_feature_branch
    given_unreachable_origin_remote

    # Act
    run call_push

    # Assert
    assert_failure
}
