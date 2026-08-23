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

@test "cud updates only dev dependencies and bumps dev constraints" {
    # Act
    run call_cud

    # Assert
    assert_success
    assert_herd_called_with "composer update vendor/direct-dev"
    assert_herd_called_with "composer bump --dev-only"
}
