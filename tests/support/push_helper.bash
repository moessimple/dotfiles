call_push() {
    zsh -c 'source "$1"; cd "$2"; push "${@:3}"' \
        zsh "$dotfiles_dir/support/git/push.sh" "$repository" "$@"
}

given_repository_with_origin() {
    given_repository_on_feature_branch
    given_bare_origin_remote
}

assert_branch_pushed_to_origin() {
    [ "$(git --git-dir="$origin" rev-parse refs/heads/feature)" = \
        "$(git -C "$repository" rev-parse feature)" ]
}
