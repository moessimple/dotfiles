#!/usr/bin/env bats

load ../../support/test_helper
load ../../support/herd_debug_ini_helper

setup() {
    new_dotfiles_fixture
    setup_herd_debug_ini_fixture
}

teardown() {
    teardown_dotfiles_fixture
}

@test "each installed PHP version gets an always-loaded xdebug.ini with the extension and mode off" {
    given_herd_reports_installed_php_versions 8.3 8.4
    given_herd_ships_xdebug_build_for 83 84
    given_herd_debug_template_is_present

    run run_herd_debug_ini_setup

    assert_success
    assert_always_loaded_xdebug_ini 83
    assert_always_loaded_xdebug_ini 84
}

@test "each installed PHP version keeps its own debug.ini for herd debug" {
    given_herd_reports_installed_php_versions 8.4
    given_herd_ships_xdebug_build_for 84
    given_herd_debug_template_is_present

    run run_herd_debug_ini_setup

    assert_success
    assert_herd_debug_ini 84
}

@test "a PHP version Herd has no Xdebug build for is skipped with a warning and no ini files" {
    given_herd_reports_installed_php_versions 8.4 8.6
    given_herd_ships_xdebug_build_for 84
    given_herd_debug_template_is_present

    run run_herd_debug_ini_setup

    assert_success
    assert_always_loaded_xdebug_ini 84
    assert_no_ini_files_for 86
    assert_output_contains "WARN: Herd has no Xdebug build for PHP 8.6"
}

@test "a PHP version Herd reports as not installed is not configured" {
    given_herd_reports_installed_php_versions 8.4
    given_herd_ships_xdebug_build_for 74 84
    given_herd_debug_template_is_present

    run run_herd_debug_ini_setup

    assert_success
    assert_no_ini_files_for 74
}

@test "re-running the setup does not overwrite an existing xdebug.ini or debug.ini" {
    given_herd_reports_installed_php_versions 8.4
    given_herd_ships_xdebug_build_for 84
    given_herd_debug_template_is_present
    given_existing_ini_file 84/xdebug.ini "xdebug.mode=develop"
    given_existing_ini_file 84/debug/debug.ini "hand-tuned by herd"

    run run_herd_debug_ini_setup

    assert_success
    assert_file_content "$(ini_path 84/xdebug.ini)" "xdebug.mode=develop"
    assert_file_content "$(ini_path 84/debug/debug.ini)" "hand-tuned by herd"
}

@test "a failing herd php:list is reported instead of claiming the ini files were installed" {
    given_herd_php_list_fails
    given_herd_ships_xdebug_build_for 84
    given_herd_debug_template_is_present

    run run_herd_debug_ini_setup

    assert_success
    assert_output_contains "WARN: Could not read Herd's PHP versions"
    assert_output_does_not_contain "SUCCESS:"
    assert_no_ini_files_for 84
}

@test "no Herd debug template found: nothing is generated and a warning is shown" {
    given_herd_reports_installed_php_versions 8.4
    given_herd_ships_xdebug_build_for 84

    run run_herd_debug_ini_setup

    assert_success
    assert_no_ini_files_for 84
    assert_output_contains "WARN: Herd's debug.ini template was not found"
}
