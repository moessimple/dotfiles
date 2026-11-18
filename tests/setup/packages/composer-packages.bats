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

@test "sourcing composer-packages.sh only defines its functions and runs no Composer command" {
    # Arrange
    given_fake_composer_reporting_installed '{"installed":[]}'

    # Act
    run run_setup_script "$target"

    # Assert
    assert_success
    [ -z "$output" ]
    assert_binary_not_called composer
}

@test "Composer withholds releases younger than 3 days in every project" {
    # Arrange
    given_fake_composer_reporting_installed '{"installed":[]}'

    # Act
    run call_setup_function "$target" install_composer_packages

    # Assert
    assert_success
    assert_binary_called_with composer "config --global policy.cooldown.period 3 days"
    assert_binary_called_with composer "config --global policy.cooldown.audit report"
}

@test "the composer-diff plugin is allow-listed with an explicit true" {
    # Arrange
    given_fake_composer_reporting_installed '{"installed":[]}'

    # Act
    run call_setup_function "$target" install_composer_packages

    # Assert
    assert_success
    assert_binary_called_with composer \
        "global config --no-plugins allow-plugins.ion-bazan/composer-diff true"
}

@test "a globally required package not declared in composer-packages.sh is removed" {
    # Arrange
    given_fake_composer_reporting_installed '{"installed":[{"name":"laravel/pint"},{"name":"foo/undeclared"}]}'

    # Act
    run call_cleanup_function "$target" clean_up_composer_packages

    # Assert
    assert_success
    assert_binary_called_with_substring composer "global remove foo/undeclared"
    assert_binary_not_called_with_substring composer "global remove laravel/pint"
}

@test "Composer cleanup reports a clean state when all global packages are declared" {
    # Arrange
    given_fake_composer_reporting_installed '{"installed":[{"name":"laravel/pint"},{"name":"cpx/cpx"}]}'

    # Act
    run call_cleanup_function "$target" clean_up_composer_packages

    # Assert
    assert_success
    assert_output_contains "No undeclared global Composer packages found"
    assert_binary_not_called_with_substring composer "global remove"
}

@test "Composer cleanup warns and removes no packages when the installed list cannot be read" {
    # Arrange
    given_fake_composer_failing_to_report_installed

    # Act
    run call_cleanup_function "$target" clean_up_composer_packages

    # Assert
    assert_success
    assert_output_contains "Could not read global Composer packages, skipping cleanup"
    assert_binary_not_called_with_substring composer "global remove"
}

@test "cleanup is skipped entirely when composer is not installed" {
    # Act
    PATH="/usr/bin:/bin" run call_cleanup_function "$target" clean_up_composer_packages

    # Assert
    assert_success
    # If the `command -v composer` guard failed to return early, the read below it would
    # still fail (composer is genuinely absent from this restricted PATH) and this warning
    # would appear, so its absence is what proves the guard fired.
    assert_output_does_not_contain "Could not read global Composer packages"
}

@test "Composer cleanup reports a failed removal of stale/one and continues with stale/two" {
    given_fake_composer_reporting_installed '{"installed":[{"name":"stale/one"},{"name":"stale/two"},{"name":"laravel/pint"}]}'
    given_command_fails_when_called_with composer "global remove stale/one"

    run call_cleanup_function "$target" clean_up_composer_packages

    assert_success
    assert_output_contains "Could not remove stale/one"
    assert_binary_called_with_substring composer "global remove stale/two"
    assert_binary_not_called_with_substring composer "global remove laravel/pint"
}
