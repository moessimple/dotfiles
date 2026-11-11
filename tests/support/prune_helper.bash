call_prune() {
    zsh -c 'source "$1"; cd "$2"; prune "${@:3}"' \
        zsh "$dotfiles_dir/support/git/prune.sh" "$repository" "$@"
}

given_repository_with_origin_on() {
    default_branch="$1"
    given_clean_repository_on_main
    git -C "$repository" branch -m "$default_branch"
    given_bare_origin_remote
    git -C "$repository" push -q origin "$default_branch"
    git --git-dir="$origin" symbolic-ref HEAD "refs/heads/$default_branch"
}

given_merged_branch_pushed_to_origin() {
    local branch="$1"
    git -C "$repository" switch -qc "$branch"
    git -C "$repository" push -qu origin "$branch"
    git -C "$repository" switch -q "$default_branch"
}

given_unmerged_branch_pushed_to_origin() {
    local branch="$1"
    git -C "$repository" switch -qc "$branch"
    printf 'unmerged change\n' > "$repository/tracked.txt"
    git -C "$repository" commit -qam "change on $branch"
    git -C "$repository" push -qu origin "$branch"
    git -C "$repository" switch -q "$default_branch"
}

given_origin_became_unreachable() {
    git -C "$repository" remote set-url origin "$fixture/missing-origin.git"
}

given_branch_with_gone_upstream() {
    local branch="$1"
    given_merged_branch_pushed_to_origin "$branch"
    git -C "$repository" push -q origin --delete "$branch"
    git -C "$repository" fetch -q origin --prune
}

# Someone else pushes a commit to the branch on origin, so origin's copy is no longer merged.
given_commit_pushed_to_origin_only() {
    local branch="$1" other="$fixture/other-clone"
    git clone -q "$origin" "$other"
    configure_test_repository "$other"
    git -C "$other" switch -q "$branch"
    git -C "$other" commit -q --allow-empty -m "more work on $branch"
    git -C "$other" push -q origin "$branch"
}
