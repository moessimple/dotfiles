#!/usr/bin/env bats

load ../support/test_helper
load ../support/commit_helper

setup() {
    new_dotfiles_fixture
    repository="$fixture/repository"
    working_directory="$repository"
    bin_dir="$fixture/bin"
    mkdir -p "$repository" "$bin_dir"
    export PATH="$bin_dir:$PATH"
    export PROVIDER_INPUT="$fixture/provider-input"
    export PROVIDER_CALLED="$fixture/provider-called"
}

teardown() {
    teardown_dotfiles_fixture
}

@test "an explicit message commits every repository change" {
    # Arrange
    given_repository_with_modified_tracked_file
    mkdir -p "$repository/nested"
    printf 'remove me\n' > "$repository/nested/removed.txt"
    git -C "$repository" add nested/removed.txt
    git -C "$repository" commit -qm fixture
    rm "$repository/nested/removed.txt"
    printf 'new\n' > "$repository/new-root.txt"

    working_directory="$repository/nested"

    # Act
    run call_commit "stage every path"

    # Assert
    assert_success
    assert_repository_is_clean
    assert_commit_message "stage every path"
    assert_commit_contains_change A new-root.txt
    assert_commit_contains_change D nested/removed.txt
    assert_commit_contains_change M tracked.txt
}

@test "Claude provides the commit message when none is given" {
    # Arrange
    given_repository_with_modified_tracked_file
    write_successful_claude "Describe the tracked change"
    write_provider_that_must_not_run codex

    # Act
    run call_commit

    # Assert
    assert_success
    assert_commit_message "Describe the tracked change"
    assert_provider_received '+changed'
    assert_provider_was_not_called
}

@test "an explicit message does not contact message providers" {
    # Arrange
    given_repository_with_modified_tracked_file
    write_providers_that_must_not_run

    # Act
    run call_commit "Use this message"

    # Assert
    assert_success
    assert_provider_was_not_called
}

@test "Codex provides the commit message when Claude fails" {
    # Arrange
    given_repository_with_modified_tracked_file
    write_failing_provider claude
    write_successful_codex "Use the Codex fallback"

    # Act
    run call_commit

    # Assert
    assert_success
    assert_commit_message "Use the Codex fallback"
    assert_provider_received '+changed'
}

@test "manual input provides the commit message when both providers fail" {
    # Arrange
    given_repository_with_modified_tracked_file
    write_failing_provider claude
    write_failing_provider codex

    # Act
    run call_commit_with_input "Write the message manually"

    # Assert
    assert_success
    assert_commit_message "Write the message manually"
}

@test "large diffs are truncated before reaching a message provider" {
    # Arrange
    given_repository_with_modified_tracked_file
    create_large_change "$repository/large.txt" START_OF_LARGE_DIFF END_OF_LARGE_DIFF
    write_successful_claude "Add the large fixture"
    write_failing_provider codex

    # Act
    run call_commit

    # Assert
    assert_success
    assert_provider_received 'START_OF_LARGE_DIFF'
    assert_provider_did_not_receive 'END_OF_LARGE_DIFF'
}

@test "empty manual input cancels the commit and keeps changes staged" {
    # Arrange
    given_repository_with_modified_tracked_file
    write_failing_provider claude
    write_failing_provider codex

    # Act
    run call_commit_with_input ""

    # Assert
    assert_failure
    assert_output_contains "Commit cancelled: no message provided."
    assert_commit_count 1
    assert_changes_are_staged
}

@test "help describes the command without staging changes" {
    # Arrange
    given_repository_with_modified_tracked_file

    # Act
    run call_commit --help

    # Assert
    assert_success
    assert_output_contains "Usage: commit [message]"
    assert_output_contains "generated via Claude/Codex or prompted for"
    assert_no_changes_are_staged
    assert_commit_count 1
}

@test "a staging failure does not contact message providers" {
    # Arrange
    repository="$fixture/not-a-repository"
    working_directory="$repository"
    mkdir -p "$repository"
    write_providers_that_must_not_run

    # Act
    run call_commit

    # Assert
    assert_failure
    assert_provider_was_not_called
}

@test "a Git commit failure is returned with changes still staged" {
    # Arrange
    given_repository_with_modified_tracked_file
    make_git_commit_fail

    # Act
    run call_commit "This commit must fail"

    # Assert
    assert_failure
    assert_commit_count 1
    assert_changes_are_staged
}
