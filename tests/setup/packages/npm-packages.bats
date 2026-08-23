#!/usr/bin/env bats

load ../../support/test_helper
load ../../support/setup_cleanup_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    target="$dotfiles_dir/support/setup/packages/npm-packages.sh"
}

teardown() {
    teardown_dotfiles_fixture
}

@test "a globally installed package not declared in npm-packages.sh is removed" {
    # Arrange
    given_fake_npm_reporting_installed '{"dependencies":{"typescript":{},"leftpad":{}}}'

    # Act
    run call_cleanup_function "$target" npm_packages_cleanup

    # Assert
    assert_success
    assert_binary_called_with_substring npm "uninstall -g leftpad"
    assert_binary_not_called_with_substring npm "uninstall -g typescript"
}

@test "a package kept for the Node toolchain itself is not removed" {
    # Arrange
    given_fake_npm_reporting_installed '{"dependencies":{"npm":{},"corepack":{},"npx":{}}}'

    # Act
    run call_cleanup_function "$target" npm_packages_cleanup

    # Assert
    assert_success
    assert_binary_not_called_with_substring npm "uninstall -g"
}

@test "no undeclared packages reports a clean state without removing anything" {
    # Arrange
    given_fake_npm_reporting_installed '{"dependencies":{"typescript":{},"intelephense":{}}}'

    # Act
    run call_cleanup_function "$target" npm_packages_cleanup

    # Assert
    assert_success
    assert_output_contains "No undeclared global npm packages found"
    assert_binary_not_called_with_substring npm "uninstall -g"
}

@test "a failed read of installed packages skips cleanup instead of removing everything" {
    # Arrange
    given_fake_npm_failing_to_report_installed

    # Act
    run call_cleanup_function "$target" npm_packages_cleanup

    # Assert
    assert_success
    assert_output_contains "Could not read global npm packages, skipping cleanup"
    assert_binary_not_called_with_substring npm "uninstall -g"
}

@test "cleanup is skipped entirely when npm is not installed" {
    # Act
    PATH="/usr/bin:/bin" run call_cleanup_function "$target" npm_packages_cleanup

    # Assert
    assert_success
    # If the `command -v npm` guard failed to return early, the read below it would still
    # fail (npm is genuinely absent from this restricted PATH) and this warning would
    # appear, so its absence is what proves the guard fired.
    assert_output_does_not_contain "Could not read global npm packages"
}
