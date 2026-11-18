call_branches() {
    zsh -c 'source "$1"; cd "$2"; branches "${@:3}"' \
        zsh "$dotfiles_dir/support/git/branches.sh" "$repository" "$@"
}

given_branch_with_commit_dates() {
    local branch="$1" author_date="$2" committer_date="$3"
    git -C "$repository" branch -q "$branch" main
    git -C "$repository" switch -q "$branch"
    GIT_AUTHOR_DATE="$author_date" GIT_COMMITTER_DATE="$committer_date" \
        git -C "$repository" commit -q --allow-empty -m "$branch"
    git -C "$repository" switch -q main
}

assert_branch_listed_before() {
    local listing
    listing=$(strip_ansi_colors "$output" | awk '{ print $NF }')
    [ "$(grep -nxF -- "$1" <<<"$listing" | cut -d: -f1)" -lt \
        "$(grep -nxF -- "$2" <<<"$listing" | cut -d: -f1)" ]
}
