#!/usr/bin/env bats

load ../support/test_helper
load ../support/composer_dependency_split_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    given_fake_composer_dependencies
}

teardown() {
    teardown_dotfiles_fixture
}

@test "cup updates only prod dependencies and bumps prod constraints" {
    # Act
    run call_cup

    # Assert
    assert_success
    assert_herd_called_with "composer update php vendor/direct-prod"
    assert_herd_called_with "composer bump --no-dev-only"
}
