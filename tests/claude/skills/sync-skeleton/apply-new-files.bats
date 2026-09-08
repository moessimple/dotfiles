#!/usr/bin/env bats

load ../../../support/sync_skeleton_helper

setup() {
    new_sync_skeleton_fixture
    given_classify_fixture
    git -C "$target" init -q
    git -C "$target" config user.name "Sync Skeleton Tests"
    git -C "$target" config user.email "sync-skeleton-tests@example.com"
}

teardown() {
    teardown_sync_skeleton_fixture
}

@test "writes and stages every gate file classified as new" {
    # Arrange
    kit_has "config/essentials.php" "<?php return ['x' => 1];"
    commit_kit

    # Act
    run_apply_new_files

    # Assert
    assert_success
    assert_output_contains "applied config/essentials.php"
    assert_file_content "$target/config/essentials.php" "<?php return ['x' => 1];"
    run git -C "$target" diff --cached --name-only
    assert_output_contains "config/essentials.php"
}

@test "leaves a differing gate file untouched" {
    # Arrange
    kit_has "pint.json" '{"preset":"laravel"}'
    project_has "pint.json" '{"preset":"mine"}'
    commit_kit

    # Act
    run_apply_new_files

    # Assert
    assert_success
    assert_file_content "$target/pint.json" '{"preset":"mine"}'
    assert_output_does_not_contain "applied pint.json"
}
