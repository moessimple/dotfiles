#!/usr/bin/env bats

load ../support/test_helper
load ../support/setup_cleanup_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    # Only the fakes and the system tools, so a Homebrew on the test machine is never found.
    export PATH="$fake_bin:/usr/bin:/bin"
    target="$dotfiles_dir/support/setup/homebrew.sh"
}

teardown() {
    teardown_dotfiles_fixture
}

# Fake curl whose downloaded installer puts a fake brew at $HOMEBREW_PREFIX/bin, which the setup
# helpers point at the fixture, so that brew lands in $fake_bin.
given_installer_that_installs_brew() {
    write_fake_binary brew
    mv "$fake_bin/brew" "$fixture/brew-installed-by-installer"
    write_fake_binary curl "echo \"mv '$fixture/brew-installed-by-installer' '$fake_bin/brew'\""
}

@test "sourcing homebrew.sh only defines its functions and runs no command" {
    # Arrange
    write_fake_binary curl
    write_fake_binary brew

    # Act
    run run_setup_script "$target"

    # Assert
    assert_success
    [ -z "$output" ]
    assert_binary_not_called curl
    assert_binary_not_called brew
}

@test "an existing Homebrew is kept without downloading the installer" {
    # Arrange
    write_fake_binary curl
    write_fake_binary brew

    # Act
    run call_setup_function "$target" install_homebrew

    # Assert
    assert_success
    assert_binary_not_called curl
    assert_output_contains "SUCCESS: Homebrew installed"
}

@test "a missing Homebrew is installed and its shellenv is loaded" {
    # Arrange
    given_installer_that_installs_brew

    # Act
    run call_setup_function "$target" install_homebrew

    # Assert
    assert_success
    assert_binary_called_with curl "-fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
    assert_binary_called_with brew "shellenv"
    assert_output_contains "SUCCESS: Homebrew installed"
}

@test "a failed Homebrew download stops setup even when the empty installer exits successfully" {
    # Arrange
    write_fake_binary curl 'exit 22'

    # Act
    run call_setup_function "$target" install_homebrew

    # Assert
    assert_failure
    assert_output_contains "ERROR: Homebrew installation failed"
    assert_output_does_not_contain "SUCCESS: Homebrew installed"
}
