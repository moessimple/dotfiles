call_switch() {
    zsh -c 'source "$1"; cd "$2"; shift 2; switch "$@"' \
        zsh "$dotfiles_dir/support/git/switch.sh" "$repository" "$@"
}

call_switch_with_stash_that_does_nothing() {
    zsh -c '
        function git() {
            if [[ "$1" == "stash" && "$2" == "push" ]]; then
                echo "No local changes to save"
                return 0
            fi
            command git "$@"
        }
        source "$1"
        cd "$2"
        switch "$3"
    ' zsh "$dotfiles_dir/support/git/switch.sh" "$repository" "$1"
}

call_switch_with_failing_stash() {
    zsh -c '
        function git() {
            if [[ "$1" == "stash" && "$2" == "push" ]]; then
                echo "simulated stash failure" >&2
                return 42
            fi
            command git "$@"
        }
        source "$1"
        cd "$2"
        switch "$3"
    ' zsh "$dotfiles_dir/support/git/switch.sh" "$repository" "$1"
}

create_conflicting_change_on_main() {
    git -C "$repository" switch -q main
    printf 'change on main\n' > "$repository/tracked.txt"
    git -C "$repository" commit -qam conflict
    git -C "$repository" switch -q feature
    printf 'local change\n' > "$repository/tracked.txt"
}

create_remote_branch() {
    local remote_name="$1"
    local branch="$2"
    local remote="$fixture/$remote_name.git"
    git init -q --bare "$remote"
    git -C "$repository" remote add "$remote_name" "$remote"
    git -C "$repository" push -q "$remote_name" "main:refs/heads/$branch"
}

stage_then_edit_tracked_file() {
    printf 'staged change\n' > "$repository/tracked.txt"
    git -C "$repository" add tracked.txt
    printf 'unstaged change\n' >> "$repository/tracked.txt"
}

assert_local_changes_are_present() {
    [ "$(cat "$repository/tracked.txt")" = "changed" ]
    [ -f "$repository/untracked.txt" ]
}

assert_file_has_merge_conflict() {
    git -C "$repository" diff --name-only --diff-filter=U | grep -qxF "$1"
}

assert_stash_contains() {
    git -C "$repository" stash show --include-untracked --patch stash@{0} | grep -Fq -- "$1"
}

assert_stash_count() {
    [ "$(git -C "$repository" stash list | wc -l | tr -d ' ')" -eq "$1" ]
}

assert_branch_does_not_exist() {
    ! git -C "$repository" show-ref --verify --quiet "refs/heads/$1"
}

assert_branch_tracks() {
    [ "$(git -C "$repository" rev-parse --abbrev-ref '@{upstream}')" = "$1" ]
}

assert_staged_file_contains() {
    [ "$(git -C "$repository" show ":$1")" = "$2" ]
}

assert_worktree_file_contains() {
    [ "$(cat "$repository/$1")" = "$2" ]
}
