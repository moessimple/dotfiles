call_prune() {
    zsh -c 'source "$1"; cd "$2"; prune "${@:3}"' \
        zsh "$dotfiles_dir/support/git/prune.sh" "$repository" "$@"
}

given_repository_with_origin_on_main() {
    given_clean_repository_on_main
    given_bare_origin_remote
    git -C "$repository" push -q origin main
    git --git-dir="$origin" symbolic-ref HEAD refs/heads/main
}

given_merged_branch_pushed_to_origin() {
    local branch="$1"
    git -C "$repository" switch -qc "$branch"
    git -C "$repository" push -qu origin "$branch"
    git -C "$repository" switch -q main
}

given_unmerged_branch_pushed_to_origin() {
    local branch="$1"
    git -C "$repository" switch -qc "$branch"
    printf 'unmerged change\n' > "$repository/tracked.txt"
    git -C "$repository" commit -qam "change on $branch"
    git -C "$repository" push -qu origin "$branch"
    git -C "$repository" switch -q main
}

given_branch_with_gone_upstream() {
    local branch="$1"
    given_merged_branch_pushed_to_origin "$branch"
    git -C "$repository" push -q origin --delete "$branch"
    git -C "$repository" fetch -q origin --prune
}

