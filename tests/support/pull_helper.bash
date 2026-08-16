call_pull() {
    zsh -c 'source "$1"; cd "$2"; pull' \
        zsh "$dotfiles_dir/support/git/pull.sh" "$repository"
}

given_origin_commit_missing_from_local_branch() {
    local changed_file="$1" new_content="$2"
    origin="$fixture/origin.git"
    git init -q --bare "$origin"
    git -C "$repository" remote add origin "$origin"
    git -C "$repository" push -qu origin feature

    local previous_commit
    previous_commit="$(git -C "$repository" rev-parse HEAD)"
    printf '%s\n' "$new_content" > "$repository/$changed_file"
    git -C "$repository" add "$changed_file"
    git -C "$repository" commit -qm "change on origin"
    git -C "$repository" push -q origin feature
    git -C "$repository" reset -q --hard "$previous_commit"
}
