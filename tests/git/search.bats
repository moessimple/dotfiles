#!/usr/bin/env bats

load ../support/test_helper
load ../support/search_helper

setup() {
    new_dotfiles_fixture
}

teardown() {
    teardown_dotfiles_fixture
}

@test "help describes search without searching anything" {
    # Arrange
    given_clean_repository_on_main

    # Act
    run call_search --help

    # Assert
    assert_success
    assert_output_contains "Usage: search <term>"
}

@test "a missing search term prints an error and searches nothing" {
    # Arrange
    given_clean_repository_on_main

    # Act
    run call_search

    # Assert
    assert_output_contains "search term required"
}

@test "a commit that introduced the term is found" {
    # Arrange
    given_clean_repository_on_main
    given_commit_adding_term needle.txt UNIQUE_TERM

    # Act
    run call_search UNIQUE_TERM

    # Assert
    assert_success
    assert_output_contains "add needle.txt"
    assert_output_contains "UNIQUE_TERM"
}

@test "a commit that removed the term is found" {
    # Arrange
    given_clean_repository_on_main
    given_commit_adding_term needle.txt UNIQUE_TERM
    given_commit_removing_term needle.txt

    # Act
    run call_search UNIQUE_TERM

    # Assert
    assert_success
    assert_output_contains "remove needle.txt"
}

@test "commits unrelated to the term are excluded" {
    # Arrange
    given_clean_repository_on_main
    given_commit_unrelated_to_term unrelated.txt

    # Act
    run call_search UNIQUE_TERM

    # Assert
    assert_success
    assert_output_does_not_contain "add unrelated unrelated.txt"
}

@test "search is case-insensitive" {
    # Arrange
    given_clean_repository_on_main
    given_commit_adding_term needle.txt UNIQUE_TERM

    # Act
    run call_search unique_term

    # Assert
    assert_success
    assert_output_contains "add needle.txt"
}
