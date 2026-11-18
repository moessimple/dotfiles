#!/usr/bin/env bats

load ../support/test_helper
load ../support/compare_helper
load ../support/fzf_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
}

teardown() {
    teardown_dotfiles_fixture
}

@test "help describes compare without diffing anything" {
    # Arrange
    given_clean_repository_on_main

    # Act
    run call_compare --help

    # Assert
    assert_success
    assert_output_contains "Usage: compare [base]"
}

@test "compare uses the remote's default branch when no base is given" {
    # Arrange
    given_clean_repository_on_main
    given_repository_with_origin_head_set_to main
    git -C "$repository" switch -qc feature
    given_committed_file_change feature-change.txt
    given_fzf_selects "feature"

    # Act
    run call_compare

    # Assert
    assert_success
    assert_output_contains "change on feature-change.txt"
}

@test "compare uses main as its base when no remote is configured" {
    # Arrange
    given_repository_on_feature_branch
    given_fzf_selects "feature"

    # Act
    run call_compare

    # Assert
    assert_success
    assert_fzf_offered_candidate "feature"
    assert_fzf_did_not_offer_candidate "main"
}

@test "compare excludes the base branch from branch selection" {
    # Arrange
    given_repository_on_feature_branch
    given_fzf_selects "feature"

    # Act
    run call_compare main

    # Assert
    assert_success
    assert_fzf_offered_candidate "feature"
    assert_fzf_did_not_offer_candidate "main"
}

@test "compare excludes release-1.0 but keeps the distinct branch release-1x0" {
    # Arrange
    given_repository_on_feature_branch
    git -C "$repository" branch release-1.0
    git -C "$repository" branch release-1x0
    given_fzf_selects "release-1x0"

    # Act
    run call_compare release-1.0

    # Assert
    assert_success
    assert_fzf_offered_candidate "release-1x0"
    assert_fzf_did_not_offer_candidate "release-1.0"
}

@test "cancelling branch selection in compare returns failure without a diff" {
    # Arrange
    given_repository_on_feature_branch
    given_fzf_selects_nothing

    # Act
    run call_compare main

    # Assert
    assert_failure
    assert_output_equals ""
}
