#!/usr/bin/env bats

load ../support/test_helper
load ../support/review_helper
load ../support/fzf_helper

setup() {
    new_dotfiles_fixture
}

teardown() {
    teardown_dotfiles_fixture
}

@test "help describes review without opening anything" {
    # Arrange
    given_clean_repository_on_main

    # Act
    run call_review --help

    # Assert
    assert_success
    assert_output_contains "Usage: review [base]"
}

@test "the base defaults to the remote's HEAD branch" {
    # Arrange
    given_clean_repository_on_main
    given_repository_with_origin_head_set_to main
    git -C "$repository" switch -qc feature
    given_committed_file_change changed-on-feature.txt
    given_fzf_selects "changed-on-feature.txt"

    # Act
    run call_review

    # Assert
    assert_success
    assert_fzf_offered_candidate "changed-on-feature.txt"
}

@test "an explicit base overrides the default branch" {
    # Arrange
    given_repository_on_feature_branch
    git -C "$repository" switch -qc other main
    given_committed_file_change changed-on-other.txt
    given_fzf_selects "changed-on-other.txt"

    # Act
    run call_review main

    # Assert
    assert_success
    assert_fzf_offered_candidate "changed-on-other.txt"
}

@test "files unchanged since the base are not offered alongside changed files" {
    # Arrange
    given_repository_on_feature_branch
    given_committed_file_change changed-on-feature.txt
    given_fzf_selects "changed-on-feature.txt"

    # Act
    run call_review main

    # Assert
    assert_success
    assert_fzf_offered_candidate "changed-on-feature.txt"
    assert_fzf_did_not_offer_candidate "tracked.txt"
}
