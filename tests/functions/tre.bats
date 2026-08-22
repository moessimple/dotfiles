#!/usr/bin/env bats

load ../support/test_helper
load ../support/tre_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    write_fake_binary tree "printf 'TREE_OUTPUT\n'"
    write_fake_binary less "cat"
}

teardown() {
    teardown_dotfiles_fixture
}

@test "tre pipes a colorized directory tree, excluding vcs and dependency folders, through less" {
    # Act
    run call_tre "docs"

    # Assert
    assert_success
    assert_binary_called_with tree "-aC -I .git|node_modules|bower_components --dirsfirst docs"
    assert_binary_called_with less "-FRNX"
    assert_output_contains "TREE_OUTPUT"
}
