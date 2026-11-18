#!/usr/bin/env bats

load ../../support/test_helper
load ../../support/setup_cleanup_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    target="$dotfiles_dir/support/setup/packages/homebrew-packages.sh"
}

teardown() {
    teardown_dotfiles_fixture
}

@test "sourcing homebrew-packages.sh only defines its functions and runs no brew command" {
    # Arrange
    write_fake_binary brew

    # Act
    run run_setup_script "$target"

    # Assert
    assert_success
    [ -z "$output" ]
    assert_binary_not_called brew
}

@test "Homebrew installation applies the repository Brewfile" {
    # Arrange
    write_fake_binary brew

    # Act
    run call_setup_function "$target" install_homebrew_packages

    # Assert
    assert_success
    assert_binary_called_with brew "bundle --file=~/.dotfiles/support/config/Brewfile"
    assert_output_contains "SUCCESS: Brewfile processed"
}

@test "a Brewfile package that fails to install is reported and the install goes on" {
    # Arrange
    write_fake_binary brew 'exit 1'

    # Act
    run call_setup_function "$target" install_homebrew_packages

    # Assert
    assert_success
    assert_output_contains "WARN: Some Brewfile packages failed to install"
}

@test "Homebrew update upgrades packages, applies the Brewfile, removes undeclared packages, and clears the download cache" {
    # Arrange
    write_fake_binary brew

    # Act
    run call_setup_function "$target" update_homebrew_packages

    # Assert
    assert_success
    assert_binary_called_with brew "update"
    assert_binary_called_with brew "upgrade"
    assert_binary_called_with brew "bundle --file=~/.dotfiles/support/config/Brewfile"
    assert_binary_called_with brew "bundle cleanup --force --file=~/.dotfiles/support/config/Brewfile"
    assert_binary_called_with brew "cleanup --prune=all"
    assert_output_contains "SUCCESS: Homebrew packages processed"
}
