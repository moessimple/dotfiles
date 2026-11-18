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
