call_sd() {
    call_dotfiles_function sd "$@"
}

# zsh's `read -q` reads the keypress directly from the controlling terminal,
# not from stdin, so piping input into it (`<<< "$1"`) only works by accident
# when there is no terminal attached (e.g. on the CI runner) and hangs on a
# real interactive prompt otherwise. Shadowing the `read` builtin sidesteps
# the terminal entirely and makes the confirmation answer deterministic.
call_sd_delete_confirmed_with() {
    local answer="$1"
    zsh -c '
        answer="$2"
        source "$1"
        read() { [[ "$answer" == y ]] }
        sd delete
    ' zsh "$functions_file" "$answer"
}

given_fake_home_for_sd() {
    fake_home="$fixture/home"
    mkdir -p "$fake_home"
    export HOME="$fake_home"
}

given_secure_data_mounted() {
    write_fake_binary mount "printf '/dev/disk9 on /Volumes/SecureData (apfs, local, journaled)\n'"
}

given_secure_data_not_mounted() {
    write_fake_binary mount
}

given_bundle_exists() {
    mkdir -p "$fake_home/SecureData.sparsebundle"
}
