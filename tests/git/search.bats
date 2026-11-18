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
    assert_failure
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
    assert_output_contains "UNIQUE_TERM"
}

@test "a commit that also changes a file without the term in the same commit is still found" {
    # Arrange
    given_clean_repository_on_main
    given_commit_adding_term_alongside_unrelated_file needle.txt UNIQUE_TERM other.txt

    # Act
    run call_search UNIQUE_TERM

    # Assert
    assert_success
    assert_output_contains "UNIQUE_TERM"
}

@test "search does not leave GREPDIFF_REGEX set in the shell" {
    # Arrange
    given_clean_repository_on_main
    given_commit_adding_term needle.txt UNIQUE_TERM

    # Act
    run call_search_then_report_regex_env UNIQUE_TERM

    # Assert
    assert_success
    assert_output_equals "<unset>"
}

@test "changes to baseline files are excluded even when they contain the term" {
    # Arrange
    given_clean_repository_on_main
    given_commit_adding_term phpstan-baseline.neon UNIQUE_TERM

    # Act
    run call_search UNIQUE_TERM

    # Assert
    assert_success
    assert_output_does_not_contain "add phpstan-baseline.neon"
}

@test "a term with regex characters shows the matching change of the commit that introduced it" {
    # Arrange
    given_clean_repository_on_main
    given_commit_adding_term query.php '$query->where(1)'

    # Act
    run call_search '->where('

    # Assert
    assert_success
    assert_output_contains "add query.php"
    assert_colorless_output_contains '+$query->where(1)'
}

@test "a term with umlauts in another case shows the matching change of the commit that introduced it" {
    # Arrange
    export LC_ALL=en_US.UTF-8
    given_clean_repository_on_main
    given_commit_adding_term notes.md 'Hinweis über Änderungen'

    # Act
    run call_search 'ÜBER ÄNDERUNGEN'

    # Assert
    assert_success
    assert_output_contains "add notes.md"
    assert_colorless_output_contains '+Hinweis über Änderungen'
}

@test "the pickaxe diff driver's ERR trap reports only to stderr" {
    # Arrange
    given_fake_bin_on_path
    write_fake_binary git 'exit 17'

    # Act
    run --separate-stderr "$dotfiles_dir/support/git/support/pickaxe-diff.sh" \
        file old oldhex 100644 new newhex 100644

    # Assert
    [ "$status" -eq 17 ]
    [ -z "$output" ]
    [[ "$stderr" == *"ERR trap"*"return code: 17"* ]] || false
}
