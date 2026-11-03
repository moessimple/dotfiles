#!/usr/bin/env bats

load ../../support/test_helper
load ../../support/setup_cleanup_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    target="$dotfiles_dir/support/setup/packages/python-packages.sh"
}

teardown() {
    teardown_dotfiles_fixture
}

@test "declared packages are installed into the user site of Homebrew's python3" {
    # Arrange
    given_fake_python_reporting_installed '[]'

    # Act
    run run_setup_script "$target"

    # Assert
    assert_success
    assert_binary_called_with_substring python3 "-m pip install --user --quiet --no-warn-script-location pandas pdf2image pdfplumber pypdf pypdfium2 pytesseract reportlab"
}

@test "a user-installed package not declared in python-packages.sh is removed" {
    # Arrange
    given_fake_python_reporting_installed '[{"name":"pypdf"},{"name":"leftpad"}]'

    # Act
    run call_cleanup_function "$target" python_packages_cleanup

    # Assert
    assert_success
    assert_binary_called_with_substring python3 "-m pip uninstall --yes --quiet leftpad"
    assert_binary_not_called_with_substring python3 "uninstall --yes --quiet pypdf"
}

@test "a declared package reported with different capitalization is not removed" {
    # Arrange
    given_fake_python_reporting_installed '[{"name":"PyPDF"},{"name":"ReportLab"}]'

    # Act
    run call_cleanup_function "$target" python_packages_cleanup

    # Assert
    assert_success
    assert_output_contains "No undeclared Python packages found"
    assert_binary_not_called_with_substring python3 "uninstall"
}

@test "a failed read of installed packages skips cleanup instead of removing everything" {
    # Arrange
    given_fake_python_failing_to_report_installed

    # Act
    run call_cleanup_function "$target" python_packages_cleanup

    # Assert
    assert_success
    assert_output_contains "Could not read user-installed Python packages, skipping cleanup"
    assert_binary_not_called_with_substring python3 "uninstall"
}

@test "cleanup is skipped entirely when python3 is not installed" {
    # Act
    PATH="/bin" run call_cleanup_function "$target" python_packages_cleanup

    # Assert
    assert_success
    assert_output_does_not_contain "Could not read user-installed Python packages"
}
