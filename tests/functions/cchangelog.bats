#!/usr/bin/env bats

load ../support/test_helper
load ../support/cchangelog_helper

setup() {
    new_dotfiles_fixture
}

teardown() {
    teardown_dotfiles_fixture
}

@test "cchangelog --direct shows direct dependency changes" {
    # Arrange
    given_direct_and_transitive_dependency_changes

    # Act
    run call_cchangelog --direct main

    # Assert
    assert_success
    assert_output_equals "vendor/direct"
}

@test "cchangelog --indirect shows only transitive dependency changes" {
    # Arrange
    given_direct_and_transitive_dependency_changes

    # Act
    run call_cchangelog --indirect main

    # Assert
    assert_success
    assert_output_equals $'vendor/package.name\nvendor/removed-package'
}

@test "cchangelog --indirect explains when no transitive dependency changed" {
    # Arrange
    given_only_direct_dependency_changes

    # Act
    run call_cchangelog --indirect main

    # Assert
    assert_success
    assert_output_equals "No indirect dependency changes."
}

@test "cchangelog --all shows direct and transitive dependency changes" {
    # Arrange
    given_direct_and_transitive_dependency_changes

    # Act
    run call_cchangelog --all main

    # Assert
    assert_success
    assert_output_equals $'vendor/direct\nvendor/transitive'
}
