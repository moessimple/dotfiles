#!/usr/bin/env bats

load ../support/test_helper
load ../support/check_helper
load ../support/fzf_helper

setup() {
    new_dotfiles_fixture
}

teardown() {
    teardown_dotfiles_fixture
}

@test "help describes check without diffing anything" {
    # Arrange
    given_clean_repository_on_main

    # Act
    run call_check --help

    # Assert
    assert_success
    assert_output_contains "Usage: check [base]"
}

@test "the base defaults to the remote's HEAD branch" {
    # Arrange
    given_clean_repository_on_main
    given_repository_with_origin_head_set_to main
    git -C "$repository" switch -qc feature
    given_committed_file_change feature-change.txt
    given_fzf_selects "feature"

    # Act
    run call_check

    # Assert
    assert_success
    assert_output_contains "change on feature-change.txt"
}

@test "the base falls back to main when the remote has no HEAD branch" {
    # Arrange
    given_repository_on_feature_branch
    given_fzf_selects "feature"

    # Act
    run call_check

    # Assert
    assert_success
    assert_fzf_offered_candidate "feature"
    assert_fzf_did_not_offer_candidate "main"
}

@test "the base branch is excluded from the selectable branches" {
    # Arrange
    given_repository_on_feature_branch
    given_fzf_selects "feature"

    # Act
    run call_check main

    # Assert
    assert_fzf_offered_candidate "feature"
    assert_fzf_did_not_offer_candidate "main"
}

@test "selecting no branch shows no diff and fails" {
    # Arrange
    given_repository_on_feature_branch
    given_fzf_selects_nothing

    # Act
    run call_check main

    # Assert
    assert_failure
    [ -z "$output" ]
}
