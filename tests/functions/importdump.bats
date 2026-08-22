#!/usr/bin/env bats

load ../support/test_helper
load ../support/database_helper

setup() {
    new_dotfiles_fixture
    working_directory="$fixture/project"
    mkdir -p "$working_directory"
    given_fake_bin_on_path
    given_fake_mysql
    given_fake_pv
    printf 'dump content\n' > "$working_directory/dump.sql"
}

teardown() {
    teardown_dotfiles_fixture
}

@test "importdump --help describes usage without importing anything" {
    # Act
    run call_importdump --help

    # Assert
    assert_success
    assert_output_contains "Usage: importdump <database> <file...>"
    assert_binary_not_called mysql
}

@test "importdump requires a database name" {
    # Act
    run call_importdump

    # Assert
    assert_failure
    assert_output_contains "database name required"
    assert_binary_not_called mysql
}

@test "importdump requires at least one SQL file" {
    # Act
    run call_importdump mydb

    # Assert
    assert_failure
    assert_output_contains "No SQL files provided."
    assert_binary_not_called mysql
}

@test "importdump streams a dump into mysql using default local credentials" {
    # Act
    run call_importdump mydb dump.sql

    # Assert
    assert_success
    assert_output_contains "Importing: dump.sql"
    assert_binary_called_with mysql "-h127.0.0.1 -uroot --force --binary-mode mydb"
}

@test "importdump uses host, user, and password from .env when present" {
    # Arrange
    given_env_file DB_HOST=dbhost DB_USERNAME=dbuser DB_PASSWORD=dbpass

    # Act
    run call_importdump mydb dump.sql

    # Assert
    assert_success
    assert_binary_called_with mysql "-hdbhost -udbuser --force --binary-mode mydb -pdbpass"
}

@test "importdump imports every given file" {
    # Arrange
    printf 'more content\n' > "$working_directory/other.sql"

    # Act
    run call_importdump mydb dump.sql other.sql

    # Assert
    assert_success
    assert_output_contains "Importing: dump.sql"
    assert_output_contains "Importing: other.sql"
    assert_binary_call_count mysql 2
}
