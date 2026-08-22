#!/usr/bin/env bats

load ../support/test_helper
load ../support/database_helper

setup() {
    new_dotfiles_fixture
    working_directory="$fixture/project"
    mkdir -p "$working_directory"
    given_fake_bin_on_path
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
    assert_binary_call_count php 2
    assert_binary_called_with php "artisan migrate"
    assert_binary_called_with php "artisan db:seed"
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
