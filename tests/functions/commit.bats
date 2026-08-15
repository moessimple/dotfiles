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
    create_commit_repository
    mkdir -p "$repository/nested"
    printf 'remove me\n' > "$repository/nested/removed.txt"
    git -C "$repository" add nested/removed.txt
    git -C "$repository" commit -qm fixture
    rm "$repository/nested/removed.txt"
    printf 'new\n' > "$repository/new-root.txt"

    working_directory="$repository/nested"
    run call_commit "stage every path"

    assert_success
    assert_repository_is_clean
    assert_commit_message "stage every path"
    assert_commit_contains_change A new-root.txt
    assert_commit_contains_change D nested/removed.txt
    assert_commit_contains_change M tracked.txt
}

@test "Claude provides the commit message when none is given" {
    create_commit_repository
    write_successful_claude "Describe the tracked change"
    write_provider_that_must_not_run codex

    run call_commit

    assert_success
    assert_commit_message "Describe the tracked change"
    assert_provider_received '+changed'
    assert_provider_was_not_called
}

@test "an explicit message does not contact message providers" {
    create_commit_repository
    write_providers_that_must_not_run

    run call_commit "Use this message"

    assert_success
    assert_provider_was_not_called
}

@test "Codex provides the commit message when Claude fails" {
    create_commit_repository
    write_failing_provider claude
    write_successful_codex "Use the Codex fallback"

    run call_commit

    assert_success
    assert_commit_message "Use the Codex fallback"
    assert_provider_received '+changed'
}

@test "manual input provides the commit message when both providers fail" {
    create_commit_repository
    write_failing_provider claude
    write_failing_provider codex

    run call_commit_with_input "Write the message manually"

    assert_success
    assert_commit_message "Write the message manually"
}

@test "large diffs are truncated before reaching a message provider" {
    create_commit_repository
    create_large_change "$repository/large.txt" START_OF_LARGE_DIFF END_OF_LARGE_DIFF
    write_successful_claude "Add the large fixture"
    write_failing_provider codex

    run call_commit

    assert_success
    assert_provider_received 'START_OF_LARGE_DIFF'
    assert_provider_did_not_receive 'END_OF_LARGE_DIFF'
}

@test "empty manual input cancels the commit and keeps changes staged" {
    create_commit_repository
    write_failing_provider claude
    write_failing_provider codex

    run call_commit_with_input ""

    assert_failure
    assert_output_contains "Commit cancelled: no message provided."
    assert_commit_count 1
    assert_changes_are_staged
}

@test "help describes the command without staging changes" {
    create_commit_repository

    run call_commit --help

    assert_success
    assert_output_contains "Usage: commit [message]"
    assert_output_contains "generated via Claude/Codex or prompted for"
    assert_no_changes_are_staged
    assert_commit_count 1
}

@test "a staging failure does not contact message providers" {
    repository="$fixture/not-a-repository"
    working_directory="$repository"
    mkdir -p "$repository"
    write_providers_that_must_not_run

    run call_commit

    assert_failure
    assert_provider_was_not_called
}

@test "a Git commit failure is returned with changes still staged" {
    create_commit_repository
    make_git_commit_fail

    run call_commit "This commit must fail"

    assert_failure
    assert_commit_count 1
    assert_changes_are_staged
}
