call_sd() {
    call_dotfiles_function sd "$@"
}

call_sd_delete_with_input() {
    call_sd delete <<< "$1"
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
