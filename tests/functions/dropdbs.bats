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

@test "dropdbs requires a .env file" {
    # Act
    run call_dropdbs

    # Assert
    assert_failure
    assert_output_contains "No .env file found."
    assert_binary_not_called mysql
}

@test "dropdbs drops only the main database when no parallel test suite is configured" {
    # Arrange
    given_env_file DB_DATABASE=maindb
    write_fake_binary mysql

    # Act
    run call_dropdbs

    # Assert
    assert_success
    assert_output_equals "Dropped: maindb"
    assert_binary_call_count mysql 1
    assert_binary_called_with mysql '-h127.0.0.1 -P3306 -uroot -e DROP DATABASE IF EXISTS `maindb`;'
}

@test "dropdbs also drops the test database and one shard per CPU when phpunit.xml declares one" {
    # Arrange
    given_env_file DB_DATABASE=maindb
    printf '<php><env name="DB_DATABASE" value="testdb"/></php>\n' > "$working_directory/phpunit.xml"
    write_fake_binary mysql
    write_fake_binary nproc "printf '2\n'"

    # Act
    run call_dropdbs

    # Assert
    assert_success
    assert_output_equals $'Dropped: maindb\nDropped: testdb\nDropped: testdb_test_1\nDropped: testdb_test_2'
    assert_binary_call_count mysql 4
}

@test "dropdbs uses the local PHPUnit configuration instead of its distribution template" {
    given_env_file DB_DATABASE=maindb
    printf '<php><env name="DB_DATABASE" value="local_test"/></php>\n' > "$working_directory/phpunit.xml"
    printf '<php><env name="DB_DATABASE" value="template_test"/></php>\n' > "$working_directory/phpunit.xml.dist"
    write_fake_binary mysql
    write_fake_binary nproc "printf '1\n'"

    run call_dropdbs

    assert_success
    assert_output_contains "Dropped: local_test"
    assert_output_does_not_contain "template_test"
    assert_binary_call_count mysql 3
}

@test "dropdbs skips a database that fails to drop and continues with the rest" {
    # Arrange
    given_env_file DB_DATABASE=maindb
    printf '<php><env name="DB_DATABASE" value="testdb"/></php>\n' > "$working_directory/phpunit.xml"
    write_fake_binary nproc "printf '1\n'"
    write_fake_binary mysql "case \"\$*\" in
    *maindb*) exit 1 ;;
esac"

    # Act
    run call_dropdbs

    # Assert
    assert_success
    assert_output_does_not_contain "Dropped: maindb"
    assert_output_contains "Dropped: testdb"
    assert_output_contains "Dropped: testdb_test_1"
}

@test "dropdbs refuses a database host that is not local" {
    # Arrange
    given_env_file DB_HOST=db.example.com DB_DATABASE=maindb
    write_fake_binary mysql
    write_fake_binary php

    # Act
    run call_dropdbs

    # Assert
    assert_failure
    assert_output_contains "db.example.com is not a local database host"
    assert_binary_not_called mysql
    assert_binary_not_called php
}
