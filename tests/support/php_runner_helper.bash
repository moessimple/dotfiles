call_p()  { call_dotfiles_function_in "$working_directory" p "$@"; }
call_pf() { call_dotfiles_function_in "$working_directory" pf "$@"; }
call_pc() { call_dotfiles_function_in "$working_directory" pc "$@"; }
call_pp() { call_dotfiles_function_in "$working_directory" pp "$@"; }

given_pest_installed() {
    mkdir -p "$working_directory/vendor/bin"
    : > "$working_directory/vendor/bin/pest"
}

given_pest_not_installed() {
    mkdir -p "$working_directory/vendor/bin"
}
