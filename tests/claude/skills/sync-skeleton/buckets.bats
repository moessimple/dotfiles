#!/usr/bin/env bats

load ../../../support/sync_skeleton_helper

setup() {
    new_sync_skeleton_fixture
}

teardown() {
    teardown_sync_skeleton_fixture
}

@test "every tracked kit path is assigned a known bucket" {
    # Arrange
    given_kit_manifest_as_fixture

    # Act
    run_classify

    # Assert
    assert_success
    assert_every_manifest_path_has_known_bucket
}

@test "the cascade and the profile catalog use the same bucket names" {
    # Arrange
    given_kit_manifest_as_fixture

    # Act
    run_classify

    # Assert
    assert_success
    assert_buckets_documented_in_profile
    assert_every_bucket_used_by_cascade
}

@test "app code and plain config are never-touch" {
    # Arrange
    given_kit_manifest_as_fixture

    # Act
    run_classify

    # Assert
    assert_success
    assert_bucket "app/Http/Controllers/Controller.php" "never-touch"
    assert_bucket "config/app.php" "never-touch"
}

@test "the quality gate, tooling, and essentials each land in their bucket" {
    # Arrange
    given_kit_manifest_as_fixture

    # Act
    run_classify

    # Assert
    assert_success
    assert_bucket ".github/workflows/lint.yml" "quality-gate"
    assert_bucket "vite.config.ts" "frontend-tooling"
    assert_bucket "config/essentials.php" "essentials"
}

@test "drift-only and out-of-scope paths are labelled as such" {
    # Arrange
    given_kit_manifest_as_fixture

    # Act
    run_classify

    # Assert
    assert_success
    assert_bucket ".gitignore" "drift-only"
    assert_bucket "artisan" "not-in-scope"
    assert_bucket "LICENSE" "not-in-scope"
}

@test "the browser suite bootstrap is appliable but browser domain tests are never-touch" {
    # Arrange
    given_kit_manifest_as_fixture

    # Act
    run_classify

    # Assert
    assert_success
    assert_bucket "tests/Browser/Pest.php" "arch-tests"
    assert_bucket "tests/Browser/WelcomeTest.php" "never-touch"
}
