#!/usr/bin/env bats

load ../support/test_helper
load ../support/dataurl_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    given_fake_mime_type_detection
    given_fake_clipboard
    printf 'hello\n' > "$fixture/notes.txt"
    printf 'hello\n' > "$fixture/photo-binary.png"
}

teardown() {
    teardown_dotfiles_fixture
}

@test "dataurl --help describes usage without encoding anything" {
    # Act
    run call_dataurl --help

    # Assert
    assert_success
    assert_output_contains "Usage: dataurl <file>"
    assert_path_does_not_exist "$fixture/clipboard"
}

@test "dataurl copies a text file as a charset-annotated data URL" {
    # Act
    run call_dataurl "$fixture/notes.txt"

    # Assert
    assert_success
    assert_output_contains "Copied to clipboard."
    assert_clipboard_content "data:text/plain;charset=utf-8;base64,aGVsbG8K"
}

@test "dataurl omits the charset for a non-text file" {
    # Act
    run call_dataurl "$fixture/photo-binary.png"

    # Assert
    assert_success
    assert_clipboard_content "data:application/octet-stream;base64,aGVsbG8K"
}
