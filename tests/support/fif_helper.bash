call_fif() {
    call_dotfiles_function fif "$@"
}

given_fzf_exits_without_a_selection() {
    write_fake_binary fzf "exit 1"
}
