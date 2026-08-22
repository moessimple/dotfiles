#!/usr/bin/env bats

load ../support/test_helper
load ../support/code_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    write_fake_binary code
}

teardown() {
    teardown_dotfiles_fixture
}

@test "code opens the current directory with the memory flag when no path is given" {
    # Act
    run call_code

    # Assert
    assert_success
    assert_binary_called_with code "-max-old-space-size=8192 ."
}

@test "code forwards a given path alongside the memory flag" {
    # Act
    run call_code "src/App.php"

    # Assert
    assert_success
    assert_binary_called_with code "-max-old-space-size=8192 src/App.php"
}
