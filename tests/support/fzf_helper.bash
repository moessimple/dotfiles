given_fzf_selects() {
    local selection="$1"
    fzf_stdin_log="$fixture/fzf-stdin"
    write_fake_binary fzf "cat > \"$fzf_stdin_log\"
printf '%s\n' \"$selection\""
}

given_fzf_selects_nothing() {
    fzf_stdin_log="$fixture/fzf-stdin"
    write_fake_binary fzf "cat > \"$fzf_stdin_log\"
exit 1"
}

assert_fzf_offered_candidate() {
    grep -qxF "$1" "$fzf_stdin_log"
}

assert_fzf_did_not_offer_candidate() {
    ! grep -qxF "$1" "$fzf_stdin_log" || false
}
