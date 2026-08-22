#!/usr/bin/env bats

load ../support/test_helper
load ../support/database_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
}

teardown() {
    teardown_dotfiles_fixture
}

@test "db --help describes usage without running anything" {
    # Act
    run call_db --help

    # Assert
    assert_success
    assert_output_contains "Usage: db <refresh|create|drop|list> [database_name]"
    assert_binary_not_called mysql
}

@test "db refresh requires a database name" {
    # Arrange
    write_fake_binary mysql

    # Act
    run call_db refresh

    # Assert
    assert_failure
    assert_output_contains "db: 'refresh' requires a database name"
    assert_binary_not_called mysql
}

@test "db refresh drops and recreates the given database" {
    # Arrange
    write_fake_binary mysql

    # Act
    run call_db refresh mydb

    # Assert
    assert_success
    assert_binary_called_with mysql '-uroot -h 127.0.0.1 -e drop database `mydb`; create database `mydb`'
}

@test "db create creates a new database" {
    # Arrange
    write_fake_binary mysql

    # Act
    run call_db create mydb

    # Assert
    assert_success
    assert_binary_called_with mysql '-uroot -h 127.0.0.1 -e create database `mydb`'
}

@test "db drop drops the given database" {
    # Arrange
    write_fake_binary mysql

    # Act
    run call_db drop mydb

    # Assert
    assert_success
    assert_binary_called_with mysql '-uroot -h 127.0.0.1 -e drop database `mydb`'
}

@test "db list shows every database, stripped of table formatting" {
    # Arrange
    write_fake_binary mysql "printf '| Database |\n| mydb |\n'"

    # Act
    run call_db list

    # Assert
    assert_success
    assert_binary_called_with mysql "-uroot -h 127.0.0.1 -e show databases"
    assert_output_equals $'Database\nmydb'
}

@test "an unknown db command is rejected" {
    # Arrange
    write_fake_binary mysql

    # Act
    run call_db bogus

    # Assert
    assert_failure
    assert_output_contains "db: unknown command 'bogus'"
    assert_binary_not_called mysql
}
