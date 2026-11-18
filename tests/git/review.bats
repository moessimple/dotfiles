#!/usr/bin/env bats

load ../support/test_helper
load ../support/review_helper
load ../support/fzf_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
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

@test "review compares changed files with the remote's default branch when no base is given" {
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

@test "review compares changed files with main when no remote is configured" {
    # Arrange
    given_repository_on_feature_branch
    given_committed_file_change changed-on-feature.txt
    given_fzf_selects "changed-on-feature.txt"

    # Act
    run call_review

    # Assert
    assert_success
    assert_fzf_offered_candidate "changed-on-feature.txt"
}

@test "review uses the explicitly selected base to exclude changes already present on that branch" {
    # Arrange
    given_repository_on_feature_branch
    given_committed_file_change shared-with-base.txt
    git -C "$repository" branch other-base
    given_committed_file_change changed-after-base.txt
    given_fzf_selects "changed-after-base.txt"

    # Act
    run call_review other-base

    # Assert
    assert_success
    assert_fzf_offered_candidate "changed-after-base.txt"
    assert_fzf_did_not_offer_candidate "shared-with-base.txt"
}

@test "review offers staged files together with files changed by branch commits" {
    # Arrange
    given_repository_on_feature_branch
    given_committed_file_change changed-on-feature.txt
    given_staged_new_file staged.txt
    given_fzf_selects "staged.txt"

    # Act
    run call_review main

    # Assert
    assert_success
    assert_fzf_offered_candidate "changed-on-feature.txt"
    assert_fzf_offered_candidate "staged.txt"
}

@test "review offers tracked files with unstaged changes" {
    # Arrange
    given_repository_on_feature_branch
    given_unstaged_change_to tracked.txt
    given_fzf_selects "tracked.txt"

    # Act
    run call_review main

    # Assert
    assert_success
    assert_fzf_offered_candidate "tracked.txt"
}

@test "review offers untracked files" {
    # Arrange
    given_repository_on_feature_branch
    given_untracked_file untracked.txt
    given_fzf_selects "untracked.txt"

    # Act
    run call_review main

    # Assert
    assert_success
    assert_fzf_offered_candidate "untracked.txt"
}

@test "review on the base branch offers uncommitted changes and excludes committed files" {
    # Arrange
    given_clean_repository_on_main
    given_committed_file_change committed-on-main.txt
    given_unstaged_change_to tracked.txt
    given_fzf_selects "tracked.txt"

    # Act
    run call_review main

    # Assert
    assert_success
    assert_fzf_offered_candidate "tracked.txt"
    assert_fzf_did_not_offer_candidate "committed-on-main.txt"
}

@test "review excludes files unchanged since the base branch" {
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
