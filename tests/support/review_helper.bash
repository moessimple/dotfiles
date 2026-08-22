call_review() {
    zsh -c 'source "$1"; cd "$2"; review "${@:3}"' \
        zsh "$dotfiles_dir/support/git/review.sh" "$repository" "$@"
}
