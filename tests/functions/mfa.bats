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
    write_fake_binary php
}

teardown() {
    teardown_dotfiles_fixture
}

@test "mfa migrates maindb, testdb, and testdb_test_1 when one CPU is available" {
    # Arrange: one CPU, a main database, and a separate PHPUnit database.
    write_fake_binary getconf "printf '1\n'"
    given_env_file DB_DATABASE=maindb
    printf '<php><env name="DB_DATABASE" value="testdb"/></php>\n' >"$working_directory/phpunit.xml"

    # Act
    run call_mfa

    # Assert
    assert_success
    assert_binary_call_count mysql 3
    assert_binary_call_count php 3
    assert_binary_called_with mysql '-h127.0.0.1 -P3306 -uroot -e DROP DATABASE IF EXISTS `maindb`; CREATE DATABASE `maindb`;'
    assert_binary_called_with mysql '-h127.0.0.1 -P3306 -uroot -e DROP DATABASE IF EXISTS `testdb`; CREATE DATABASE `testdb`;'
    assert_binary_called_with mysql '-h127.0.0.1 -P3306 -uroot -e DROP DATABASE IF EXISTS `testdb_test_1`; CREATE DATABASE `testdb_test_1`;'
}

@test "mfa attempts the test databases after the main migration fails and returns failure" {
    # Arrange: one CPU, a main database, and a separate PHPUnit database.
    write_fake_binary getconf "printf '1\n'"
    given_env_file DB_DATABASE=maindb
    printf '<php><env name="DB_DATABASE" value="testdb"/></php>\n' >"$working_directory/phpunit.xml"
    # The main migration fails; both test database migrations succeed.
    write_fake_binary php "printf '%s\n' \"\$DB_DATABASE\" >> \"$fixture/attempted-migrations\"
[ \"\$DB_DATABASE\" != maindb ]"

    # Act
    run call_mfa

    # Assert
    assert_failure
    assert_binary_call_count mysql 3
    assert_binary_call_count php 3
    assert_file_content "$fixture/attempted-migrations" $'maindb\ntestdb\ntestdb_test_1'
}

@test "mfa refuses a database host that is not local" {
    # Arrange
    given_env_file DB_HOST=db.example.com DB_DATABASE=maindb

    # Act
    run call_mfa

    # Assert
    assert_failure
    assert_output_contains "db.example.com is not a local database host"
    assert_binary_not_called mysql
    assert_binary_not_called php
}
