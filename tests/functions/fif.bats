#!/usr/bin/env bats

load ../support/test_helper
load ../support/fif_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    given_fzf_exits_without_a_selection
}

teardown() {
    teardown_dotfiles_fixture
}

@test "fif pre-fills the fzf query with the given search term" {
    # Act
    run call_fif "TODO"

    # Assert
    assert_binary_called_with_substring fzf "--disabled --query TODO"
}

@test "fif starts with an empty query when no search term is given" {
    # Act
    run call_fif

    # Assert (two spaces: the query argument itself is empty)
    assert_binary_called_with_substring fzf "--disabled --query  --bind"
}
