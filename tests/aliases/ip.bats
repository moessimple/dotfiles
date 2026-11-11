#!/usr/bin/env bats

load ../support/test_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    write_fake_binary curl
}

teardown() {
    teardown_dotfiles_fixture
}

@test "ip looks up the public address over HTTPS" {
    # Act
    run call_dotfiles_alias ip

    # Assert
    assert_success
    assert_binary_called_with curl "https://ifconfig.me/ip"
}
