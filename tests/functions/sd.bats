#!/usr/bin/env bats

load ../support/test_helper
load ../support/sd_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    given_fake_home_for_sd
    write_fake_binary hdiutil
}

teardown() {
    teardown_dotfiles_fixture
}

@test "sd --help describes usage without touching the volume" {
    # Act
    run call_sd --help

    # Assert
    assert_success
    assert_output_contains "Usage: sd <load|unload|delete|status>"
    assert_binary_not_called hdiutil
}

@test "sd load creates and attaches a new sparse bundle when none exists yet" {
    # Arrange
    given_secure_data_not_mounted

    # Act
    run call_sd load

    # Assert
    assert_success
    assert_binary_called_with hdiutil \
        "create -size 20g -type SPARSEBUNDLE -fs APFS -volname SecureData -encryption AES-256 -stdinpass $fake_home/SecureData.sparsebundle"
    assert_binary_called_with hdiutil "attach $fake_home/SecureData.sparsebundle"
}

@test "sd load only attaches an existing sparse bundle" {
    # Arrange
    given_secure_data_not_mounted
    given_bundle_exists

    # Act
    run call_sd load

    # Assert
    assert_success
    assert_binary_call_count hdiutil 1
    assert_binary_called_with hdiutil "attach $fake_home/SecureData.sparsebundle"
}

@test "sd load reports an already mounted volume instead of attaching it again" {
    # Arrange
    given_bundle_exists
    given_secure_data_mounted

    # Act
    run call_sd load

    # Assert
    assert_success
    assert_output_contains "SecureData is already mounted."
    assert_binary_not_called hdiutil
}

@test "sd unload detaches a mounted volume" {
    # Arrange
    given_secure_data_mounted

    # Act
    run call_sd unload

    # Assert
    assert_success
    assert_binary_called_with hdiutil "detach /Volumes/SecureData"
}

@test "sd unload reports when the volume is not mounted" {
    # Arrange
    given_secure_data_not_mounted

    # Act
    run call_sd unload

    # Assert
    assert_success
    assert_output_contains "SecureData is not mounted."
    assert_binary_not_called hdiutil
}

@test "sd status reports a mounted volume" {
    # Arrange
    given_secure_data_mounted

    # Act
    run call_sd status

    # Assert
    assert_success
    assert_output_contains "SecureData is mounted at /Volumes/SecureData."
}

@test "sd status reports an unmounted volume" {
    # Arrange
    given_secure_data_not_mounted

    # Act
    run call_sd status

    # Assert
    assert_success
    assert_output_contains "SecureData is not mounted."
}

@test "sd delete cancels without deleting anything when not confirmed with y" {
    # Arrange
    given_secure_data_not_mounted
    given_bundle_exists

    # Act
    run call_sd_delete_confirmed_with "n"

    # Assert
    assert_failure
    assert_path_exists "$fake_home/SecureData.sparsebundle"
    assert_binary_not_called hdiutil
}

@test "sd delete detaches and deletes a mounted, existing bundle when confirmed" {
    # Arrange
    given_secure_data_mounted
    given_bundle_exists

    # Act
    run call_sd_delete_confirmed_with "y"

    # Assert
    assert_success
    assert_binary_called_with hdiutil "detach /Volumes/SecureData"
    assert_path_does_not_exist "$fake_home/SecureData.sparsebundle"
}

@test "sd delete reports when the bundle does not exist" {
    # Arrange
    given_secure_data_not_mounted

    # Act
    run call_sd_delete_confirmed_with "y"

    # Assert
    assert_success
    assert_output_contains "SecureData does not exist."
    assert_binary_not_called hdiutil
}

@test "an unknown sd command is rejected" {
    # Act
    run call_sd bogus

    # Assert
    assert_failure
    assert_output_contains "sd: unknown command 'bogus'"
    assert_binary_not_called hdiutil
}
