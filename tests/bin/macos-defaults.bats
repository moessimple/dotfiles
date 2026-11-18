#!/usr/bin/env bats

load ../support/test_helper
load ../support/macos_defaults_helper

setup() {
    new_dotfiles_fixture
    given_path_without_system_commands
    target="$dotfiles_dir/bin/macos-defaults.sh"
}

teardown() {
    teardown_dotfiles_fixture
}

@test "the macos-defaults entry point keeps the confirmation prompt and cancellation" {
    # Act
    run run_standalone_answering n "$dotfiles_dir/bin/macos-defaults.sh"

    # Assert
    assert_success
    assert_output_contains "This will change macOS system settings."
    assert_output_contains "Cancelled."
}

@test "confirmed macOS setup applies security settings and keeps battery hibernation" {
    given_fake_macos_commands

    run run_standalone_answering y "$target"

    assert_success
    assert_binary_called_with_args sudo -v
    assert_binary_called_with_args sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
    assert_binary_called_with_args defaults write com.apple.screensaver askForPassword -int 1
    assert_binary_called_with_args defaults write com.apple.screencapture location "$restricted_home/Screenshots"
    assert_binary_not_called_with_substring sudo "fdesetup enable"
    assert_binary_not_called_with_substring sudo "hibernatemode"
    [ "$(/usr/libexec/PlistBuddy -c 'Print :DesktopViewSettings:IconViewSettings:arrangeBy' "$restricted_home/Library/Preferences/com.apple.finder.plist")" = grid ]
    assert_output_contains "macOS defaults configured!"
}

@test "confirmed macOS setup enables FileVault and disables hibernation without a battery" {
    given_fake_macos_commands

    TEST_FILEVAULT_STATUS="FileVault is Off." TEST_BATTERY_STATUS="AC Power" run run_standalone_answering y "$target"

    assert_success
    assert_binary_called_with_args sudo fdesetup enable
    assert_binary_called_with_args sudo pmset -a hibernatemode 0
}

@test "a failed macOS preference write stops setup without claiming completion" {
    given_fake_macos_commands
    write_fake_binary defaults 'exit 17'

    run run_standalone_answering y "$target"

    assert_status 17
    assert_output_does_not_contain "macOS defaults configured!"
    assert_binary_not_called killall
}
