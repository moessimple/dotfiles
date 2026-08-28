call_review() {
    zsh -c 'source "$1"; cd "$2"; review "${@:3}"' \
        zsh "$dotfiles_dir/support/git/review.sh" "$repository" "$@"
}

given_repository_with_origin_head_set_to() {
    local branch="$1"
    given_bare_origin_remote
    git -C "$repository" push -q origin "$branch"
    # The bare remote's own HEAD, not just the local cached copy, since
    # the default-branch resolver reads it live via `git ls-remote --symref`.
    git --git-dir="$origin" symbolic-ref HEAD "refs/heads/$branch"
    git -C "$repository" symbolic-ref "refs/remotes/origin/HEAD" "refs/remotes/origin/$branch"
}
