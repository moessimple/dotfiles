#!/usr/bin/env bats

load ../support/test_helper
load ../support/database_helper

setup() {
    new_dotfiles_fixture
    working_directory="$fixture/project"
    mkdir -p "$working_directory"
    given_fake_bin_on_path
    write_fake_binary mysql
    write_fake_binary php "printf 'DB_DATABASE=%s\n' \"\$DB_DATABASE\" >> \"$fake_bin/php.calls\""
    given_env_file DB_DATABASE=maindb
}

teardown() {
    teardown_dotfiles_fixture
}

@test "mf recreates the main database and migrates it via artisan" {
    # Act
    run call_mf

    # Assert
    assert_success
    assert_binary_called_with mysql '-h127.0.0.1 -uroot -e DROP DATABASE IF EXISTS `maindb`; CREATE DATABASE `maindb`;'
    assert_binary_called_with php "artisan migrate"
    assert_binary_called_with php "DB_DATABASE=maindb"
}

@test "mf pushes the schema via skeema instead of migrating when database/skeema exists" {
    # Arrange
    mkdir -p "$working_directory/database/skeema"

    # Act
    run call_mf

    # Assert
    assert_success
    assert_binary_called_with php "artisan skeema:push --allow-unsafe --force --skip-lint --env=local"
    assert_binary_called_with php "DB_DATABASE=maindb"
}
