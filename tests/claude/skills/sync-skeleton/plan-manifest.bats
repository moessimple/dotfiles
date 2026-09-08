#!/usr/bin/env bats

load ../../../support/sync_skeleton_helper

setup() {
    new_sync_skeleton_fixture
    given_classify_fixture
}

teardown() {
    teardown_sync_skeleton_fixture
}

@test "a kit require-dev entry the project lacks becomes an add" {
    # Arrange
    kit_manifest "$(manifest_json require-dev roave/security-advisories dev-latest laravel/pint '^1.27')"
    project_manifest "$(manifest_json require-dev laravel/pint '^1.27')"
    commit_kit

    # Act
    run_plan_manifest

    # Assert
    assert_success
    assert_directive add php roave/security-advisories dev-latest
    assert_no_directive_for laravel/pint
}

@test "a shared require-dev entry at a different constraint becomes an align to the kit's" {
    # Arrange
    kit_manifest "$(manifest_json require-dev larastan/larastan '^3.9')"
    project_manifest "$(manifest_json require-dev larastan/larastan '^3.11')"
    commit_kit

    # Act
    run_plan_manifest

    # Assert
    assert_success
    assert_directive align php larastan/larastan '^3.9'
}

@test "a project-only dev tool the kit never had is left untouched" {
    # Arrange
    kit_manifest "$(manifest_json require-dev laravel/pint '^1.27')"
    project_manifest "$(manifest_json require-dev laravel/pint '^1.27' barryvdh/laravel-debugbar '^3.15')"
    commit_kit

    # Act
    run_plan_manifest

    # Assert
    assert_success
    assert_no_directive_for barryvdh/laravel-debugbar
}

@test "a project eslint or prettier devDependency the kit dropped becomes a remove" {
    # Arrange
    kit_manifest "" "$(manifest_json devDependencies vite-plus 0.3.0 vue-tsc '^2.2')"
    project_manifest "" "$(manifest_json devDependencies vue-tsc '^2.2' eslint '^9.39' prettier-plugin-tailwindcss '^0.6')"
    commit_kit

    # Act
    run_plan_manifest

    # Assert
    assert_success
    assert_directive add npm vite-plus 0.3.0
    assert_directive remove npm eslint '^9.39'
    assert_directive remove npm prettier-plugin-tailwindcss '^0.6'
}

@test "an eslint devDependency is kept when the kit still carries an eslint family member" {
    # Arrange
    kit_manifest "" "$(manifest_json devDependencies eslint-plugin-custom '^1.0')"
    project_manifest "" "$(manifest_json devDependencies eslint-plugin-custom '^1.0' eslint '^9.39')"
    commit_kit

    # Act
    run_plan_manifest

    # Assert
    assert_success
    assert_no_directive_for eslint
}

@test "runtime require and dependencies are never inspected" {
    # Arrange
    kit_manifest \
        "$(manifest_json require nunomaduro/essentials '^1.2')" \
        "$(manifest_json dependencies vue '^3.5')"
    project_manifest \
        "$(manifest_json require laravel/framework '^12.0')" \
        "$(manifest_json dependencies vue '^3.4')"
    commit_kit

    # Act
    run_plan_manifest

    # Assert
    assert_success
    assert_output_equals ""
}
