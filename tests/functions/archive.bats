#!/usr/bin/env bats

load ../support/test_helper
load ../support/archive_helper

setup() {
    new_dotfiles_fixture
    mkdir -p "$fixture/build folder"
    printf 'archived content' >"$fixture/build folder/file.txt"
}

teardown() {
    teardown_dotfiles_fixture
}

@test "archive creates a readable ZIP containing the selected directory" {
    run call_archive "build folder"

    assert_success
    assert_file_exists "$fixture/build folder.zip"
    run /usr/bin/unzip -p "$fixture/build folder.zip" "build folder/file.txt"
    assert_success
    assert_output_equals "archived content"
}
