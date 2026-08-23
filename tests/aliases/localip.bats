#!/usr/bin/env bats

load ../support/test_helper
load ../support/localip_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    given_fake_ifconfig_with_mixed_addresses
}

teardown() {
    teardown_dotfiles_fixture
}

@test "localip extracts IPv4 and IPv6 addresses without interface labels or zone IDs" {
    # Act
    run call_localip

    # Assert
    assert_success
    assert_output_equals $'127.0.0.1\n::1\nfe80::1234:5678:9abc:def0\n192.168.1.42'
}
