#!/usr/bin/env bats

load ../support/test_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
}

teardown() {
    teardown_dotfiles_fixture
}

@test "path lists one PATH entry per line" {
    # Act
    run env PATH="/first/bin:/second/bin:$PATH" zsh -c 'source "$1"; eval path' zsh "$aliases_file"

    # Assert
    assert_success
    assert_output_contains $'/first/bin\n/second/bin\n'
}
