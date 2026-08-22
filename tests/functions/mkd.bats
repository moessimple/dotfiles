#!/usr/bin/env bats

load ../support/test_helper
load ../support/mkd_helper

setup() {
    new_dotfiles_fixture
    working_directory="$fixture/workspace"
    mkdir -p "$working_directory"
}

teardown() {
    teardown_dotfiles_fixture
}

@test "mkd creates a nested directory and changes into it" {
    # Act
    run call_mkd "a/b/c"

    # Assert
    assert_success
    assert_output_equals "$working_directory/a/b/c"
    assert_path_exists "$working_directory/a/b/c"
}

@test "mkd succeeds and enters a directory that already exists" {
    # Arrange
    mkdir -p "$working_directory/existing"

    # Act
    run call_mkd "existing"

    # Assert
    assert_success
    assert_output_equals "$working_directory/existing"
}
