#!/usr/bin/env bats

load ../support/test_helper
load ../support/archive_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    write_fake_binary zip
}

teardown() {
    teardown_dotfiles_fixture
}

@test "archive zips the given file or directory into a matching .zip" {
    # Act
    run call_archive "build"

    # Assert
    assert_success
    assert_binary_called_with zip "-r build.zip build"
}
