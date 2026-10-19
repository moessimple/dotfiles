#!/usr/bin/env bats

load ../../../support/test_helper
load ../../../support/explain_changes_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
}

teardown() {
    teardown_dotfiles_fixture
}

@test "traces a replaced line to the pull request that introduced it" {
    # Arrange
    given_repository_with_file charge.php 'charge();\n'
    commit_file charge.php 'guard();\ncharge();\n' "Add guard"
    given_github_origin
    given_github_returns_pull_request 6 "Prevent double charges" "Charging twice refunded nothing."
    switch_to_branch feature
    commit_file charge.php 'charge();\n' "Remove guard"

    # Act
    run_history_for_branch feature

    # Assert
    assert_success
    assert_output_contains "Add guard"
    assert_output_contains "lines: charge.php:1"
    assert_output_contains "pr: #6 Prevent double charges"
    assert_output_contains "url: https://github.com/acme/app/pull/6"
    assert_output_contains "    Charging twice refunded nothing."
    assert_binary_called_with_substring gh "repos/acme/app/commits/$(commit_sha "Add guard")/pulls"
}

@test "folds consecutive removed lines from one commit into a range" {
    # Arrange
    given_repository_with_file notes.txt 'one\ntwo\nthree\nfour\nfive\n'
    switch_to_branch feature
    commit_file notes.txt 'one\nfive\n' "Drop the middle"

    # Act
    run_history_for_branch feature

    # Assert
    assert_success
    assert_output_contains "lines: notes.txt:2-4"
}

@test "reports a change that only adds code" {
    # Arrange
    given_repository_with_file notes.txt 'one\n'
    switch_to_branch feature
    commit_file notes.txt 'one\ntwo\n' "Append a line"

    # Act
    run_history_for_branch feature

    # Assert
    assert_success
    assert_output_equals "No removed or replaced lines: the change only adds code."
}

@test "traces lines that uncommitted changes remove" {
    # Arrange
    given_repository_with_file notes.txt 'one\n'
    commit_file notes.txt 'kept for audits\n' "Keep audit line"
    switch_to_branch feature
    change_file_without_committing notes.txt 'gone\n'

    # Act
    run_history_for_working_tree

    # Assert
    assert_success
    assert_output_contains "Keep audit line"
}

@test "blames the merge base rather than a base branch that moved on" {
    # Arrange
    given_repository_with_file notes.txt 'one\n'
    commit_file notes.txt 'original\n' "Introduce the original line"
    switch_to_branch feature
    commit_file notes.txt 'feature\n' "Replace on feature"
    switch_to_branch main
    commit_file notes.txt 'rewritten\n' "Rewrite on main"

    # Act
    run_history_for_branch feature

    # Assert
    assert_success
    assert_output_contains "Introduce the original line"
    assert_output_does_not_contain "Rewrite on main"
}

@test "falls back to the commit message when no pull request introduced the commit" {
    # Arrange
    given_repository_with_file notes.txt 'one\n'
    commit_file_with_reason notes.txt 'retry three times\n' "Add retries" "The upstream API drops one request in fifty."
    given_github_origin
    given_github_returns_no_pull_request
    switch_to_branch feature
    commit_file notes.txt 'retry once\n' "Reduce retries"

    # Act
    run_history_for_branch feature

    # Assert
    assert_success
    assert_output_contains "pr: none"
    assert_output_contains "    The upstream API drops one request in fifty."
}

@test "does not query GitHub when origin is not a GitHub repository" {
    # Arrange
    given_repository_with_file notes.txt 'one\n'
    given_github_returns_no_pull_request
    switch_to_branch feature
    commit_file notes.txt 'two\n' "Replace the line"

    # Act
    run_history_for_branch feature

    # Assert
    assert_success
    assert_output_contains "pr: not looked up, origin is not a GitHub repository"
    assert_binary_not_called gh
}

@test "reports a failed pull request lookup and keeps going" {
    # Arrange
    given_repository_with_file notes.txt 'one\n'
    given_github_origin
    given_github_is_unreachable
    switch_to_branch feature
    commit_file notes.txt 'two\n' "Replace the line"

    # Act
    run_history_for_branch feature

    # Assert
    assert_success
    assert_output_contains "pr: lookup failed (gh api)"
    assert_output_contains "    initial"
}

@test "traces removed lines in a Git-quoted filename" {
    given_repository_with_file 'notes"quoted.txt' 'old\n'
    switch_to_branch feature
    commit_file 'notes"quoted.txt' 'new\n' "Replace the line"

    run_history_for_branch feature

    assert_success
    assert_output_contains 'lines: notes"quoted.txt:1'
    assert_output_contains "    initial"
}

@test "preserves backslashes in filenames" {
    given_repository_with_file 'notes\backslash.txt' 'old\n'
    switch_to_branch feature
    commit_file 'notes\backslash.txt' 'new\n' "Replace the line"

    run_history_for_branch feature

    assert_success
    assert_output_contains 'lines: notes\backslash.txt:1'
}

@test "traces a renamed file using its merge-base path" {
    given_repository_with_file old.txt 'old\n'
    switch_to_branch feature
    git -C "$repository" mv old.txt new.txt
    git -C "$repository" commit -qm "Rename the file"

    run_history_for_branch feature

    assert_success
    assert_output_contains 'lines: old.txt:1'
    assert_output_contains "    initial"
}

@test "reports unsupported filename delimiters instead of claiming additions only" {
    given_repository_with_file $'notes\ttab.txt' 'old\n'
    switch_to_branch feature
    commit_file $'notes\ttab.txt' 'new\n' "Replace the line"

    run_history_for_branch feature

    [ "$status" -ne 0 ]
    assert_output_contains "filenames containing tabs or newlines are not supported"
    assert_output_does_not_contain "the change only adds code"
}
