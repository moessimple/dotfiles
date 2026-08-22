call_mkd() {
    zsh -c 'cd "$1" && source "$2" && mkd "$3" && pwd' \
        zsh "$working_directory" "$functions_file" "$@"
}
