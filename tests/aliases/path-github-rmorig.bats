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

@test "github opens the current directory in GitHub Desktop" {
    # Arrange
    write_fake_binary open
    project="$fixture/project"
    mkdir -p "$project"

    # Act
    run zsh -c 'source "$1"; cd "$2"; eval github' zsh "$aliases_file" "$project"

    # Assert
    assert_success
    assert_binary_called_with open "-a /Applications/GitHub Desktop.app $project"
}

@test "rmorig removes .orig files at any depth and keeps everything else" {
    # Arrange
    tree="$fixture/tree"
    mkdir -p "$tree/nested/deeper"
    touch "$tree/top.orig" "$tree/nested/deeper/inner.orig" "$tree/keep.php"

    # Act
    run zsh -c 'source "$1"; cd "$2"; eval rmorig' zsh "$aliases_file" "$tree"

    # Assert
    assert_success
    assert_path_does_not_exist "$tree/top.orig"
    assert_path_does_not_exist "$tree/nested/deeper/inner.orig"
    assert_path_exists "$tree/keep.php"
}
