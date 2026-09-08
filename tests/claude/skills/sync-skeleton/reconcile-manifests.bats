#!/usr/bin/env bats

load ../../../support/sync_skeleton_helper

setup() {
    new_sync_skeleton_fixture
    given_plain_project
    given_fake_bin_on_path
}

teardown() {
    teardown_sync_skeleton_fixture
}

@test "regenerates composer.lock when composer.json and composer.lock both exist" {
    # Arrange
    printf '{}\n' > "$target/composer.json"
    printf '{}\n' > "$target/composer.lock"
    write_fake_binary composer "exit 0"

    # Act
    run_reconcile

    # Assert
    assert_success
    assert_binary_called_with_substring composer "update --lock --no-interaction"
}

@test "runs the detected JS package manager for package.json" {
    # Arrange
    printf '{}\n' > "$target/package.json"
    printf '{}\n' > "$target/pnpm-lock.yaml"
    write_fake_binary pnpm "exit 0"

    # Act
    run_reconcile

    # Assert
    assert_success
    assert_binary_called_with_substring pnpm "install"
}

@test "retries JS install once after wiping node_modules and the lockfile" {
    # Arrange
    printf '{}\n' > "$target/package.json"
    printf 'lock\n' > "$target/package-lock.json"
    mkdir -p "$target/node_modules/x"
    write_fake_binary npm 'test -d "'"$target"'/node_modules" && exit 1 || exit 0'

    # Act
    run_reconcile

    # Assert
    assert_success
    assert_binary_call_count npm 2
    assert_path_does_not_exist "$target/node_modules"
}

@test "bad arguments exit 64" {
    # Act
    run env PATH="$fake_bin:$PATH" bash "$reconcile"

    # Assert
    assert_status 64
}
