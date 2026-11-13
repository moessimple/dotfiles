#!/usr/bin/env bats

load ../../support/test_helper
load ../../support/osx_defaults_helper

setup() {
    new_dotfiles_fixture
    given_path_without_system_commands
    target="$dotfiles_dir/support/setup/macos/osx-defaults.sh"
}

teardown() {
    teardown_dotfiles_fixture
}

@test "declining the macOS defaults lets the setup script that sourced them carry on" {
    # Act
    run source_from_setup_script_answering n "$target"

    # Assert
    assert_success
    assert_output_contains "Setup script continued"
}

@test "declining the macOS defaults on a standalone run exits cleanly" {
    # Act
    run run_standalone_answering n "$target"

    # Assert
    assert_success
    assert_output_contains "Cancelled."
}
