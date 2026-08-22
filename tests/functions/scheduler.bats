#!/usr/bin/env bats

load ../support/test_helper
load ../support/scheduler_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    write_fake_binary php
    given_sleep_stops_the_loop_after_two_iterations
}

teardown() {
    teardown_dotfiles_fixture
}

@test "scheduler reruns php artisan schedule:run every 60 seconds" {
    # Act
    run call_scheduler

    # Assert
    assert_binary_call_count php 2
    assert_binary_called_with php "artisan schedule:run"
    assert_output_contains "Sleeping 60 seconds..."
    assert_binary_called_with sleep "60"
}
