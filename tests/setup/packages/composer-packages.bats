#!/usr/bin/env bats

load ../../support/test_helper
load ../../support/setup_cleanup_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    target="$dotfiles_dir/support/setup/packages/composer-packages.sh"
}

teardown() {
    teardown_dotfiles_fixture
}

@test "a globally required package not declared in composer-packages.sh is removed" {
    # Arrange
    given_fake_composer_reporting_installed '{"installed":[{"name":"laravel/pint"},{"name":"foo/undeclared"}]}'

    # Act
    run call_cleanup_function "$target" composer_packages_cleanup

    # Assert
    assert_success
    assert_binary_called_with_substring composer "global remove foo/undeclared"
    assert_binary_not_called_with_substring composer "global remove laravel/pint"
}

@test "no undeclared packages reports a clean state without removing anything" {
    # Arrange
    given_fake_composer_reporting_installed '{"installed":[{"name":"laravel/pint"},{"name":"cpx/cpx"}]}'

    # Act
    run call_cleanup_function "$target" composer_packages_cleanup

    # Assert
    assert_success
    assert_output_contains "No undeclared global Composer packages found"
    assert_binary_not_called_with_substring composer "global remove"
}

@test "a failed read of installed packages skips cleanup instead of removing everything" {
    # Arrange
    given_fake_composer_failing_to_report_installed

    # Act
    run call_cleanup_function "$target" composer_packages_cleanup

    # Assert
    assert_success
    assert_output_contains "Could not read global Composer packages, skipping cleanup"
    assert_binary_not_called_with_substring composer "global remove"
}

@test "cleanup is skipped entirely when composer is not installed" {
    # Act
    PATH="/usr/bin:/bin" run call_cleanup_function "$target" composer_packages_cleanup

    # Assert
    assert_success
    # If the `command -v composer` guard failed to return early, the read below it would
    # still fail (composer is genuinely absent from this restricted PATH) and this warning
    # would appear, so its absence is what proves the guard fired.
    assert_output_does_not_contain "Could not read global Composer packages"
}
