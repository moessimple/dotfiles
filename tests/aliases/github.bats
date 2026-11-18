#!/usr/bin/env bats

load ../support/test_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
}

teardown() {
    teardown_dotfiles_fixture
}

@test "github opens the current directory in GitHub Desktop" {
    # Arrange
    write_fake_binary open
    project="$fixture/project"
    mkdir -p "$project"

    # Act
    run zsh -c 'source "$1"; cd "$2"; eval github' zsh "$aliases_file" "$project"

    # Assert
    assert_success
    assert_binary_called_with_args open -a "/Applications/GitHub Desktop.app" "$project"
}
