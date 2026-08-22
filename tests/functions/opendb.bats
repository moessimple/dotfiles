#!/usr/bin/env bats

load ../support/test_helper
load ../support/database_helper

setup() {
    new_dotfiles_fixture
    working_directory="$fixture/project"
    mkdir -p "$working_directory"
    given_fake_bin_on_path
    write_fake_binary open
}

teardown() {
    teardown_dotfiles_fixture
}

@test "opendb requires a .env file" {
    # Act
    run call_opendb

    # Assert
    assert_failure
    assert_output_contains "No .env file found."
    assert_binary_not_called open
}

@test "opendb requires DB_HOST to be set in .env" {
    # Arrange
    given_env_file DB_CONNECTION=mysql DB_PORT=3306 DB_DATABASE=mydb DB_USERNAME=root

    # Act
    run call_opendb

    # Assert
    assert_failure
    assert_output_contains "DB_HOST not found in .env file."
    assert_binary_not_called open
}

@test "opendb opens the database in a GUI client using credentials from .env" {
    # Arrange
    given_env_file \
        DB_CONNECTION=mysql DB_HOST=127.0.0.1 DB_PORT=3306 \
        DB_DATABASE=mydb DB_USERNAME=root DB_PASSWORD=secret

    # Act
    run call_opendb

    # Assert
    assert_success
    assert_binary_called_with open "mysql://root:secret@127.0.0.1:3306/mydb"
}

@test "opendb opens with an empty password when DB_PASSWORD is not set" {
    # Arrange
    given_env_file DB_CONNECTION=mysql DB_HOST=127.0.0.1 DB_PORT=3306 DB_DATABASE=mydb DB_USERNAME=root

    # Act
    run call_opendb

    # Assert
    assert_success
    assert_binary_called_with open "mysql://root:@127.0.0.1:3306/mydb"
}
