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

@test "sourcing python-packages.sh only defines its functions and runs no pip command" {
    # Arrange
    given_fake_python_reporting_installed '[]'

    # Act
    run run_setup_script "$target"

    # Assert
    assert_success
    [ -z "$output" ]
    assert_binary_not_called python3
}

@test "declared packages are installed into the user site of Homebrew's python3" {
    # Arrange
    given_fake_python_reporting_installed '[]'

    # Act
    run call_setup_function "$target" install_python_packages

    # Assert
    assert_success
    assert_binary_called_with_substring python3 "-m pip install --user"
    assert_binary_called_with_substring python3 "pdfplumber"
}

@test "pip runs with Homebrew's externally-managed lock lifted, which it otherwise refuses" {
    # Arrange
    given_fake_python_reporting_installed '[{"name":"leftpad"}]'

    # Act
    run call_setup_function "$target" install_python_packages update_python_packages clean_up_python_packages

    # Assert
    assert_success
    assert_binary_called_with_substring python3 "PIP_BREAK_SYSTEM_PACKAGES=1 -m pip install --user --quiet --no-warn-script-location --uploaded-prior-to P3D pandas"
    assert_binary_called_with_substring python3 "PIP_BREAK_SYSTEM_PACKAGES=1 -m pip install --user --quiet --no-warn-script-location --uploaded-prior-to P3D --upgrade"
    assert_binary_called_with_substring python3 "PIP_BREAK_SYSTEM_PACKAGES=1 -m pip list"
    assert_binary_called_with_substring python3 "PIP_BREAK_SYSTEM_PACKAGES=1 -m pip uninstall"
}

@test "a user-installed package not declared in python-packages.sh is removed" {
    # Arrange
    given_fake_python_reporting_installed '[{"name":"pypdf"},{"name":"leftpad"}]'

    # Act
    run call_cleanup_function "$target" clean_up_python_packages

    # Assert
    assert_success
    assert_binary_called_with_substring python3 "-m pip uninstall --yes --quiet leftpad"
    assert_binary_not_called_with_substring python3 "uninstall --yes --quiet pypdf"
}

@test "a declared package reported with different capitalization is not removed" {
    # Arrange
    given_fake_python_reporting_installed '[{"name":"PyPDF"},{"name":"ReportLab"}]'

    # Act
    run call_cleanup_function "$target" clean_up_python_packages

    # Assert
    assert_success
    assert_output_contains "No undeclared Python packages found"
    assert_binary_not_called_with_substring python3 "uninstall"
}

@test "a failed read of installed packages skips cleanup instead of removing everything" {
    # Arrange
    given_fake_python_failing_to_report_installed

    # Act
    run call_cleanup_function "$target" clean_up_python_packages

    # Assert
    assert_success
    assert_output_contains "Could not read user-installed Python packages, skipping cleanup"
    assert_binary_not_called_with_substring python3 "uninstall"
}

@test "cleanup is skipped entirely when python3 is not installed" {
    # Act
    PATH="/bin" run call_cleanup_function "$target" clean_up_python_packages

    # Assert
    assert_success
    assert_output_does_not_contain "Could not read user-installed Python packages"
}

@test "install and update apply a three-day cooldown without passing it to list or uninstall" {
    given_fake_python_reporting_installed '[{"name":"leftpad"}]'

    run call_setup_function "$target" install_python_packages update_python_packages clean_up_python_packages

    assert_success
    local call installs=0
    while IFS= read -r call; do
        if [[ "$call" == *"-m pip install "* ]]; then
            [[ "$call" == *"--uploaded-prior-to P3D"* ]] || false
            installs="$((installs + 1))"
        else
            [[ "$call" != *"--uploaded-prior-to"* ]] || false
        fi
    done <"$fake_bin/python3.calls"
    [ "$installs" -eq 2 ]
}

@test "a failed removal is reported while remaining undeclared entries are still removed" {
    given_fake_python_reporting_installed '[{"name":"stale-one"},{"name":"stale-two"},{"name":"pypdf"}]'
    printf '\ncase "$*" in "-m pip uninstall --yes --quiet stale-one "*) exit 17 ;; esac\n' >>"$fake_bin/python3"

    run call_cleanup_function "$target" clean_up_python_packages

    assert_success
    assert_output_contains "Could not remove stale-one"
    assert_binary_called_with_substring python3 "-m pip uninstall --yes --quiet stale-two"
    assert_binary_not_called_with_substring python3 "uninstall --yes --quiet pypdf"
}
