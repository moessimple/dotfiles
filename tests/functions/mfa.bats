#!/usr/bin/env bats

load ../support/test_helper
load ../support/database_helper

setup() {
    new_dotfiles_fixture
    working_directory="$fixture/project"
    mkdir -p "$working_directory"
    given_fake_bin_on_path
    write_fake_binary mysql
    write_fake_binary php
    write_fake_binary nproc "printf '1\n'"
    given_env_file DB_DATABASE=maindb
    printf '<php><env name="DB_DATABASE" value="testdb"/></php>\n' > "$working_directory/phpunit.xml"
}

teardown() {
    teardown_dotfiles_fixture
}

@test "mfa migrates the main database, the test database, and one shard per CPU" {
    # Act
    run call_mfa

    # Assert
    assert_success
    assert_binary_call_count mysql 3
    assert_binary_call_count php 3
    assert_binary_called_with mysql '-h127.0.0.1 -uroot -e DROP DATABASE IF EXISTS `maindb`; CREATE DATABASE `maindb`;'
    assert_binary_called_with mysql '-h127.0.0.1 -uroot -e DROP DATABASE IF EXISTS `testdb`; CREATE DATABASE `testdb`;'
    assert_binary_called_with mysql '-h127.0.0.1 -uroot -e DROP DATABASE IF EXISTS `testdb_test_1`; CREATE DATABASE `testdb_test_1`;'
}
