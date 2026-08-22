#!/usr/bin/env bats

load ../support/test_helper
load ../support/removehost_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    write_fake_binary ssh-keygen
}

teardown() {
    teardown_dotfiles_fixture
}

@test "removehost removes the given host's entry from known_hosts" {
    # Act
    run call_removehost "example.com"

    # Assert
    assert_success
    assert_binary_called_with ssh-keygen "-R example.com"
}
