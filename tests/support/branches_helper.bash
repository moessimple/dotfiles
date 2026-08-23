call_branches() {
    zsh -c 'source "$1"; cd "$2"; branches "${@:3}"' \
        zsh "$dotfiles_dir/support/git/branches.sh" "$repository" "$@"
}
