#!/usr/bin/env bats

load ../support/test_helper
load ../support/database_helper

setup() {
    new_dotfiles_fixture
    working_directory="$fixture/project"
    mkdir -p "$working_directory"
    given_fake_bin_on_path
    write_fake_binary mysql
    write_fake_binary nproc "printf '1\n'"
    given_env_file DB_DATABASE=maindb
    printf '<php><env name="DB_DATABASE" value="testdb"/></php>\n' > "$working_directory/phpunit.xml"
}

teardown() {
    teardown_dotfiles_fixture
}

@test "mfsa migrates every database and then seeds once" {
    # Arrange
    write_fake_binary php

    # Act
    run call_mfsa

    # Assert
    assert_success
    assert_binary_call_count php 4
    assert_binary_called_with php "artisan db:seed"
}

@test "mfsa still migrates every database when the first one fails, but skips seeding" {
    # Arrange: the loop never stops early, so all three databases are still
    # attempted even though the first one (maindb) fails.
    write_fake_binary php "[ \"\$DB_DATABASE\" != maindb ]"

    # Act
    run call_mfsa

    # Assert
    assert_failure
    assert_binary_call_count php 3
}
