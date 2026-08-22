#!/usr/bin/env bats

load ../support/test_helper
load ../support/cmdp_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    write_fake_binary rush "cat >/dev/null"
}

teardown() {
    teardown_dotfiles_fixture
}

@test "cmdp --help describes usage without running anything" {
    # Act
    run call_cmdp --help

    # Assert
    assert_success
    assert_output_contains "Usage: cmdp <n> <command>"
    assert_binary_not_called rush
}

@test "cmdp requires a process count" {
    # Act
    run call_cmdp

    # Assert
    assert_failure
    assert_binary_not_called rush
}

@test "cmdp rejects a non-numeric process count" {
    # Act
    run call_cmdp abc echo hi

    # Assert
    assert_failure
    assert_output_contains "cmdp: n must be a positive integer"
    assert_binary_not_called rush
}

@test "cmdp rejects a process count below one" {
    # Act
    run call_cmdp 0 echo hi

    # Assert
    assert_failure
    assert_output_contains "cmdp: n must be a positive integer"
    assert_binary_not_called rush
}

@test "cmdp requires a command" {
    # Act
    run call_cmdp 3

    # Assert
    assert_failure
    assert_output_contains "cmdp: command required"
    assert_binary_not_called rush
}

@test "cmdp runs a single-word command n times in parallel via rush" {
    # Act
    run call_cmdp 4 echo

    # Assert
    assert_success
    assert_binary_called_with rush "-j 4 -I echo"
}

@test "cmdp joins a multi-word command into a single rush template" {
    # Act
    run call_cmdp 2 date +%s

    # Assert
    assert_success
    assert_binary_called_with rush "-j 2 -I date +%s"
}
