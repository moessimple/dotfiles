call_pw()  { call_dotfiles_function pw "$@"; }
call_pwf() { call_dotfiles_function pwf "$@"; }

given_phpunit_watcher_on_path() {
    write_fake_binary phpunit-watcher
}
