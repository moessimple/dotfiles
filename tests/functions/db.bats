#!/usr/bin/env bats

load ../support/test_helper
load ../support/database_helper

setup() {
    new_dotfiles_fixture
    working_directory="$fixture/project"
    mkdir -p "$working_directory"
    given_fake_bin_on_path
    given_herd_forwarding_php_and_composer
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

@test "db refresh drops and recreates the given database using default local credentials" {
    # Arrange
    write_fake_binary mysql

    # Act
    run call_db refresh mydb

    # Assert
    assert_success
    assert_binary_called_with mysql '-h127.0.0.1 -P3306 -uroot -e drop database `mydb`; create database `mydb`'
}

@test "db create creates a new database" {
    # Arrange
    write_fake_binary mysql

    # Act
    run call_db create mydb

    # Assert
    assert_success
    assert_binary_called_with mysql '-h127.0.0.1 -P3306 -uroot -e create database `mydb`'
}

@test "db drop drops the given database" {
    # Arrange
    write_fake_binary mysql

    # Act
    run call_db drop mydb

    # Assert
    assert_success
    assert_binary_called_with mysql '-h127.0.0.1 -P3306 -uroot -e drop database `mydb`'
}

@test "db list shows every database, stripped of table formatting" {
    # Arrange
    write_fake_binary mysql "printf '| Database |\n| mydb |\n'"

    # Act
    run call_db list

    # Assert
    assert_success
    assert_binary_called_with mysql "-h127.0.0.1 -P3306 -uroot -e show databases"
    assert_output_equals $'Database\nmydb'
}

@test "db uses host, user, and password from .env when present" {
    # Arrange
    given_env_file DB_HOST=::1 DB_USERNAME=dbuser DB_PASSWORD=dbpass
    write_fake_binary mysql

    # Act
    run call_db create mydb

    # Assert
    assert_success
    assert_binary_called_with mysql '-h::1 -P3306 -udbuser -e create database `mydb` -pdbpass'
}

@test "db removes quotes around .env values" {
    # Arrange
    given_env_file 'DB_USERNAME="dbuser"' "DB_PASSWORD='secret word'"
    write_fake_binary mysql

    # Act
    run call_db create mydb

    # Assert
    assert_success
    assert_binary_called_with mysql '-h127.0.0.1 -P3306 -udbuser -e create database `mydb` -psecret word'
}

@test "db connects to the port from .env" {
    # Arrange
    given_env_file DB_PORT=3307
    write_fake_binary mysql

    # Act
    run call_db create mydb

    # Assert
    assert_success
    assert_binary_called_with mysql '-h127.0.0.1 -P3307 -uroot -e create database `mydb`'
}

@test "db connects to localhost over TCP so the port from .env applies" {
    # Arrange
    given_env_file DB_HOST=localhost DB_PORT=3307
    write_fake_binary mysql

    # Act
    run call_db create mydb

    # Assert
    assert_success
    assert_binary_called_with mysql '-h127.0.0.1 -P3307 -uroot -e create database `mydb`'
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

@test "db refresh refuses a database host that is not local" {
    # Arrange
    given_env_file DB_HOST=db.example.com DB_DATABASE=maindb
    write_fake_binary mysql
    write_fake_binary php

    # Act
    run call_db refresh maindb

    # Assert
    assert_failure
    assert_output_contains "db.example.com is not a local database host"
    assert_binary_not_called mysql
    assert_binary_not_called php
}

@test "db drop refuses a database host that is not local" {
    # Arrange
    given_env_file DB_HOST=db.example.com DB_DATABASE=maindb
    write_fake_binary mysql
    write_fake_binary php

    # Act
    run call_db drop maindb

    # Assert
    assert_failure
    assert_output_contains "db.example.com is not a local database host"
    assert_binary_not_called mysql
    assert_binary_not_called php
}

@test "db create refuses a database host that is not local" {
    given_env_file DB_HOST=db.example.com
    write_fake_binary mysql

    run call_db create mydb

    assert_failure
    assert_output_contains "db.example.com is not a local database host"
    assert_binary_not_called mysql
}
