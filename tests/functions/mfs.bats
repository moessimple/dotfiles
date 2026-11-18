#!/usr/bin/env bats

load ../support/test_helper
load ../support/database_helper

setup() {
    new_dotfiles_fixture
    working_directory="$fixture/project"
    mkdir -p "$working_directory"
    given_fake_bin_on_path
    given_herd_forwarding_php_and_composer
    write_fake_binary mysql
    given_env_file DB_DATABASE=maindb
}

teardown() {
    teardown_dotfiles_fixture
}

@test "mfs migrates the main database and then seeds it" {
    # Arrange
    write_fake_binary php

    # Act
    run call_mfs

    # Assert
    assert_success
    assert_file_content "$fake_bin/php.calls" $'artisan migrate\nartisan db:seed'
}

@test "mfs does not seed when the migration fails" {
    # Arrange
    write_fake_binary php "case \"\$*\" in
    *migrate*) exit 1 ;;
esac"

    # Act
    run call_mfs

    # Assert
    assert_failure
    assert_binary_call_count php 1
    assert_binary_called_with php "artisan migrate"
}

@test "mfs refuses a database host that is not local" {
    # Arrange
    given_env_file DB_HOST=db.example.com DB_DATABASE=maindb
    write_fake_binary php

    # Act
    run call_mfs

    # Assert
    assert_failure
    assert_output_contains "db.example.com is not a local database host"
    assert_binary_not_called mysql
    assert_binary_not_called php
}

@test "mfs stops before migration and seeding when recreating the database fails" {
    write_fake_binary mysql 'exit 1'
    write_fake_binary php

    run call_mfs

    assert_failure
    assert_binary_call_count mysql 1
    assert_binary_not_called php
}
