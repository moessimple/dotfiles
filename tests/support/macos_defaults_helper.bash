# Runs bin/macos-defaults.sh with an empty PATH and a HOME whose ~/.dotfiles holds the output
# helpers, so a regression past the confirmation prompt fails on the first missing command
# (osascript, sudo) instead of changing this machine's settings.
given_path_without_system_commands() {
    restricted_path="$BATS_TEST_TMPDIR/restricted-bin"
    restricted_home="$BATS_TEST_TMPDIR/home"
    mkdir -p "$restricted_path" "$restricted_home/.dotfiles"
    cp -R "$dotfiles_dir/support" "$restricted_home/.dotfiles/"
}

run_standalone_answering() {
    local answer="$1" script="$2"
    HOME="$restricted_home" PATH="$restricted_path" /bin/bash "$script" <<<"$answer"
}

# The only absolute executable is PlistBuddy, which writes solely to this fixture HOME.
# Privileged commands are recorded by sudo and never forwarded to the host.
given_fake_macos_commands() {
    given_fake_bin_on_path
    local tool
    for tool in osascript sudo defaults chflags killall; do
        write_fake_binary "$tool"
    done
    write_fake_binary fdesetup 'printf "%s\n" "${TEST_FILEVAULT_STATUS:-FileVault is On.}"'
    write_fake_binary pmset 'printf "%s\n" "${TEST_BATTERY_STATUS:-InternalBattery}"'
    write_fake_binary sleep 'exit 1'
    ln -s /bin/bash "$fake_bin/bash"
    ln -s /usr/bin/grep "$fake_bin/grep"
    mkdir -p "$restricted_home/Library/Preferences"
    restricted_path="$fake_bin"
}
