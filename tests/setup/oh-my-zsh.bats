#!/usr/bin/env bats

load ../support/test_helper
load ../support/setup_cleanup_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    test_home="$fixture/home"
    mkdir -p "$test_home"
    target="$dotfiles_dir/support/setup/oh-my-zsh.sh"
}

teardown() {
    teardown_dotfiles_fixture
}

@test "an existing Oh My Zsh installation is kept without downloading an installer" {
    # Arrange
    mkdir -p "$test_home/.oh-my-zsh"
    write_fake_binary curl

    # Act
    run call_setup_function "$target" install_oh_my_zsh

    # Assert
    assert_success
    assert_binary_not_called curl
    assert_output_contains "SUCCESS: Oh My Zsh already installed"
}

@test "a missing Oh My Zsh installation runs the downloaded installer unattended" {
    # Arrange: the downloaded installer creates Oh My Zsh only when it is started with --unattended.
    cat >"$fixture/installer.sh" <<'INSTALLER'
[ "$*" = "--unattended" ] || exit 1
mkdir -p "$HOME/.oh-my-zsh"
INSTALLER
    write_fake_binary curl "cat \"$fixture/installer.sh\""

    # Act
    run call_setup_function "$target" install_oh_my_zsh

    # Assert
    assert_success
    [ -d "$test_home/.oh-my-zsh" ]
    assert_binary_called_with_args curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh
    assert_output_contains "SUCCESS: Oh My Zsh installed"
}

@test "a failed Oh My Zsh download warns even when the empty installer exits successfully" {
    # Arrange
    write_fake_binary curl 'exit 22'

    # Act
    run call_setup_function "$target" install_oh_my_zsh

    # Assert
    assert_success
    assert_output_contains "WARN: Oh My Zsh installation failed"
    assert_output_does_not_contain "SUCCESS:"
    assert_path_does_not_exist "$test_home/.oh-my-zsh"
}

@test "an installer that succeeds without creating Oh My Zsh is reported as a failure" {
    # Arrange
    write_fake_binary curl 'printf "exit 0"'

    # Act
    run call_setup_function "$target" install_oh_my_zsh

    # Assert
    assert_success
    assert_output_contains "WARN: Oh My Zsh installation failed"
    assert_output_does_not_contain "SUCCESS:"
}
