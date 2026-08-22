call_merge() {
    zsh -c 'source "$1"; cd "$2"; merge "${@:3}"' \
        zsh "$dotfiles_dir/support/git/merge.sh" "$repository" "$@"
}
