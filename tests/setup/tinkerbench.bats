#!/usr/bin/env bats

load ../support/test_helper
load ../support/setup_cleanup_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    test_home="$fixture/home"
    mkdir -p "$test_home/Code"
    target="$dotfiles_dir/support/setup/tinkerbench/tinkerbench.sh"
}

teardown() {
    teardown_dotfiles_fixture
}

@test "a tinkerbench clone that fails is reported and the run continues" {
    # Arrange
    write_fake_binary git 'exit 128'

    # Act
    run call_setup_function "$target" tinkerbench_setup

    # Assert
    assert_success
    assert_output_contains "WARN: Could not clone tinkerbench"
    assert_output_does_not_contain "SUCCESS:"
}

@test "a tinkerbench setup that fails is reported and the run continues" {
    # Arrange
    mkdir -p "$test_home/Code/tinkerbench"
    write_fake_binary composer 'exit 1'

    # Act
    run call_setup_function "$target" tinkerbench_setup

    # Assert
    assert_success
    assert_output_contains "WARN: Could not set up tinkerbench"
    assert_output_does_not_contain "SUCCESS:"
}

@test "an existing tinkerbench checkout without .env runs the project's own setup" {
    # Arrange
    mkdir -p "$test_home/Code/tinkerbench"
    write_fake_binary composer

    # Act
    run call_setup_function "$target" tinkerbench_setup

    # Assert
    assert_success
    assert_binary_called_with composer "setup"
    assert_output_contains "SUCCESS: tinkerbench.test ready"
}
