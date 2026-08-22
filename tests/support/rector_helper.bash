call_rector() {
    call_dotfiles_function_in "$working_directory" rector "$@"
}

given_rector_installed_locally() {
    mkdir -p "$working_directory/vendor/bin"
    : > "$working_directory/vendor/bin/rector"
}
