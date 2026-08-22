call_check() {
    zsh -c 'source "$1"; cd "$2"; check "${@:3}"' \
        zsh "$dotfiles_dir/support/git/check.sh" "$repository" "$@"
}

given_repository_with_origin_head_set_to() {
    local branch="$1"
    given_bare_origin_remote
    git -C "$repository" push -q origin "$branch"
    git -C "$repository" symbolic-ref "refs/remotes/origin/HEAD" "refs/remotes/origin/$branch"
}
