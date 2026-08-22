#!/usr/bin/env bats

load ../support/test_helper
load ../support/pw_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    given_phpunit_watcher_on_path
    write_fake_binary php "printf 'PHP_OPTIONS=%s\n' \"\$PHP_OPTIONS\" >> \"$fake_bin/php.calls\""
}

teardown() {
    teardown_dotfiles_fixture
}

@test "pw watches and reruns tests with testdox output and an increased memory limit" {
    # Act
    run call_pw

    # Assert
    assert_success
    assert_binary_called_with_substring php "watch --testdox"
    assert_binary_called_with php "PHP_OPTIONS=-d memory_limit=8192M"
}

@test "pw forwards extra arguments to phpunit-watcher" {
    # Act
    run call_pw "--group=slow"

    # Assert
    assert_success
    assert_binary_called_with_substring php "watch --testdox --group=slow"
}
