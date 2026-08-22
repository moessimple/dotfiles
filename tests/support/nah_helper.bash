call_nah() {
    zsh -c 'source "$1"; cd "$2"; nah "${@:3}"' \
        zsh "$dotfiles_dir/support/git/nah.sh" "$repository" "$@"
}

given_conflicting_merge_in_progress() {
    git -C "$repository" switch -qc other
    printf 'other change\n' > "$repository/tracked.txt"
    git -C "$repository" commit -qam "change on other"
    git -C "$repository" switch -q main
    printf 'main change\n' > "$repository/tracked.txt"
    git -C "$repository" commit -qam "change on main"
    git -C "$repository" merge other || true
}

given_conflicting_rebase_in_progress() {
    git -C "$repository" switch -qc other
    printf 'other change\n' > "$repository/tracked.txt"
    git -C "$repository" commit -qam "change on other"
    git -C "$repository" switch -q main
    printf 'main change\n' > "$repository/tracked.txt"
    git -C "$repository" commit -qam "change on main"
    git -C "$repository" switch -q other
    git -C "$repository" rebase main || true
}

given_conflicting_cherry_pick_in_progress() {
    git -C "$repository" switch -qc other
    printf 'other change\n' > "$repository/tracked.txt"
    git -C "$repository" commit -qam "change on other"
    git -C "$repository" switch -q main
    printf 'main change\n' > "$repository/tracked.txt"
    git -C "$repository" commit -qam "change on main"
    git -C "$repository" cherry-pick other || true
}

given_conflicting_revert_in_progress() {
    printf 'v1\n' > "$repository/tracked.txt"
    git -C "$repository" commit -qam "tracked.txt to v1"
    local revertable_commit
    revertable_commit="$(git -C "$repository" rev-parse HEAD)"
    printf 'v2\n' > "$repository/tracked.txt"
    git -C "$repository" commit -qam "tracked.txt to v2"
    git -C "$repository" revert --no-edit "$revertable_commit" || true
}

given_bisect_in_progress() {
    git -C "$repository" commit -q --allow-empty -m "second commit"
    git -C "$repository" commit -q --allow-empty -m "third commit"
    git -C "$repository" bisect start
    git -C "$repository" bisect bad
    git -C "$repository" bisect good HEAD~2
}

assert_no_merge_in_progress() {
    [ ! -f "$(git -C "$repository" rev-parse --absolute-git-dir)/MERGE_HEAD" ]
}

assert_no_rebase_in_progress() {
    local git_dir
    git_dir="$(git -C "$repository" rev-parse --absolute-git-dir)"
    [ ! -d "$git_dir/rebase-merge" ] && [ ! -d "$git_dir/rebase-apply" ]
}

assert_no_cherry_pick_in_progress() {
    [ ! -f "$(git -C "$repository" rev-parse --absolute-git-dir)/CHERRY_PICK_HEAD" ]
}

assert_no_revert_in_progress() {
    [ ! -f "$(git -C "$repository" rev-parse --absolute-git-dir)/REVERT_HEAD" ]
}

assert_bisect_session_still_recorded() {
    [ -f "$(git -C "$repository" rev-parse --absolute-git-dir)/BISECT_LOG" ]
}
