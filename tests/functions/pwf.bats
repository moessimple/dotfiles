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

@test "pwf watches and reruns tests filtered by name" {
    # Act
    run call_pwf "it computes the total"

    # Assert
    assert_success
    assert_binary_called_with_substring php "watch --testdox --filter it computes the total"
    assert_binary_called_with php "PHP_OPTIONS=-d memory_limit=8192M"
}
