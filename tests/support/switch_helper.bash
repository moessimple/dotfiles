given_switch_repository_on_feature_branch() {
    given_repository_on_feature_branch
    git -C "$repository" config checkout.defaultRemote no-such-remote
}

call_switch() {
    zsh -c 'source "$1"; cd "$2"; shift 2; switch "$@"' \
        zsh "$dotfiles_dir/support/git/switch.sh" "$repository" "$@"
}

# The bring/leave/cancel choice uses a plain `read -r`, which reads from stdin like any
# other input and can be piped.
call_switch_with_input() {
    local input="$1"
    shift
    call_switch "$@" <<< "$input"
}

# The overwrite-stash confirmation uses zsh's `read -q`, which reads the keypress directly
# from the controlling terminal rather than stdin (see the note in sd_helper.bash for the
# same issue). Shadowing `read` only for `-q` calls keeps the choice prompt reading normally
# from the piped stdin below, while making the confirmation answer deterministic.
call_switch_choosing_leave_and_confirming_overwrite_with() {
    local confirm_answer="$1" branch="$2"
    zsh -c '
        confirm_answer="$1"
        source "$2"
        cd "$3"
        read() {
            if [[ "$1" == "-q" ]]; then
                [[ "$confirm_answer" == y ]]
            else
                builtin read "$@"
            fi
        }
        switch "$4" <<< "1"
    ' zsh "$confirm_answer" "$dotfiles_dir/support/git/switch.sh" "$repository" "$branch"
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
        switch "$3" <<< "2"
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
        switch "$3" <<< "2"
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

assert_file_has_merge_conflict() {
    git -C "$repository" diff --name-only --diff-filter=U | grep -qxF "$1"
}

assert_staged_file_contains() {
    [ "$(git -C "$repository" show ":$1")" = "$2" ]
}

assert_worktree_file_contains() {
    [ "$(cat "$repository/$1")" = "$2" ]
}

assert_stash_marked_for() {
    git -C "$repository" stash list | grep -qF "!!dotfiles-switch<$1>"
}
