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
}

teardown() {
    teardown_dotfiles_fixture
}

@test "mfsa migrates the main and test databases before seeding once" {
    # Arrange: one CPU, a main database, and a separate PHPUnit database.
    write_fake_binary getconf "printf '1\n'"
    given_env_file DB_DATABASE=maindb
    printf '<php><env name="DB_DATABASE" value="testdb"/></php>\n' >"$working_directory/phpunit.xml"
    write_fake_binary php

    # Act
    run call_mfsa

    # Assert
    assert_success
    assert_file_content "$fake_bin/php.calls" $'artisan migrate\nartisan migrate\nartisan migrate\nartisan db:seed'
}

@test "mfsa attempts the test databases after the main migration fails and does not seed" {
    # Arrange: one CPU, a main database, and a separate PHPUnit database.
    write_fake_binary getconf "printf '1\n'"
    given_env_file DB_DATABASE=maindb
    printf '<php><env name="DB_DATABASE" value="testdb"/></php>\n' >"$working_directory/phpunit.xml"
    # The main migration fails; both test database migrations succeed.
    write_fake_binary php "printf '%s\n' \"\$DB_DATABASE\" >> \"$fixture/attempted-migrations\"
[ \"\$DB_DATABASE\" != maindb ]"

    # Act
    run call_mfsa

    # Assert
    assert_failure
    assert_binary_call_count php 3
    assert_file_content "$fixture/attempted-migrations" $'maindb\ntestdb\ntestdb_test_1'
    assert_binary_not_called_with_substring php "db:seed"
}
