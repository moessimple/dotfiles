call_importdump() { call_dotfiles_function_in "$working_directory" importdump "$@"; }
call_db()         { call_dotfiles_function_in "$working_directory" db "$@"; }
call_dropdbs()    { call_dotfiles_function_in "$working_directory" dropdbs "$@"; }
call_mf()         { call_dotfiles_function_in "$working_directory" mf "$@"; }
call_mfs()        { call_dotfiles_function_in "$working_directory" mfs "$@"; }
call_mfa()        { call_dotfiles_function_in "$working_directory" mfa "$@"; }
call_mfsa()       { call_dotfiles_function_in "$working_directory" mfsa "$@"; }
call_opendb()     { call_dotfiles_function_in "$working_directory" opendb "$@"; }

# Writes .env with one KEY=VALUE per argument, e.g. given_env_file DB_HOST=dbhost DB_USERNAME=dbuser
given_env_file() {
    printf '%s\n' "$@" > "$working_directory/.env"
}

given_fake_mysql() {
    write_fake_binary mysql "cat >/dev/null"
}

given_fake_pv() {
    write_fake_binary pv "cat \"\$1\""
}
