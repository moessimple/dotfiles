#!/usr/bin/env bats

load ../support/test_helper
load ../support/digga_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    write_fake_binary dig
}

teardown() {
    teardown_dotfiles_fixture
}

@test "digga looks up all DNS records for a domain in multiline format" {
    # Act
    run call_digga "example.com"

    # Assert
    assert_success
    assert_binary_called_with dig "+nocmd example.com any +multiline +noall +answer"
}
