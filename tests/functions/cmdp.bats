#!/usr/bin/env bats

load ../support/test_helper
load ../support/cmdp_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    write_fake_binary rush "cat >\"$fixture/rush-input\""
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
    assert_output_contains "cmdp: n must be a positive integer"
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

@test "cmdp requests four parallel executions of the supplied command" {
    # Act
    run call_cmdp 4 echo

    # Assert
    assert_success
    assert_binary_called_with_args rush -j 4 -I echo
    assert_file_content "$fixture/rush-input" $'1\n2\n3\n4'
}

@test "cmdp passes the command and its arguments as one executable template to rush" {
    # Act
    run call_cmdp 2 date +%s

    # Assert
    assert_success
    assert_binary_called_with_args rush -j 2 -I "date +%s"
    assert_file_content "$fixture/rush-input" $'1\n2'
}
