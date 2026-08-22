new_dotfiles_fixture() {
    dotfiles_dir="$(cd "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
    functions_file="$dotfiles_dir/home/.functions"
    fixture="$BATS_TEST_TMPDIR/dotfiles-fixture"
    mkdir -p "$fixture"
}

teardown_dotfiles_fixture() {
    rm -rf -- "$fixture"
}

# Sources home/.functions in a fresh zsh process and calls the named function
# with the remaining arguments. Shared by every tests/functions/*_helper.bash
# so each one only defines a thin call_<name> wrapper around this.
call_dotfiles_function() {
    zsh -c 'source "$1"; local name="$2"; shift 2; "$name" "$@"' \
        zsh "$functions_file" "$@"
}

# Same as call_dotfiles_function, but changes into the given directory first,
# for functions that read relative paths like .env or vendor/bin/*.
call_dotfiles_function_in() {
    local directory="$1"
    shift
    zsh -c 'cd "$1" && source "$2"; local name="$3"; shift 3; "$name" "$@"' \
        zsh "$directory" "$functions_file" "$@"
}

# Puts a directory of fake executables ahead of PATH so functions under test
# invoke test doubles instead of the real external tools.
given_fake_bin_on_path() {
    fake_bin="$fixture/bin"
    mkdir -p "$fake_bin"
    export PATH="$fake_bin:$PATH"
}

# Writes a fake executable that records its arguments (one call per line, in
# "$fake_bin/<name>.calls") and then runs the given body, if any.
write_fake_binary() {
    local name="$1" body="${2:-}"
    cat > "$fake_bin/$name" <<SCRIPT
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$fake_bin/$name.calls"
$body
SCRIPT
    chmod +x "$fake_bin/$name"
}

assert_binary_called_with() {
    grep -qxF -- "$2" "$fake_bin/$1.calls"
}

assert_binary_called_with_substring() {
    grep -qF -- "$2" "$fake_bin/$1.calls"
}

assert_binary_call_count() {
    [ "$(wc -l < "$fake_bin/$1.calls" | tr -d ' ')" -eq "$2" ]
}

assert_binary_not_called() {
    [ ! -f "$fake_bin/$1.calls" ]
}

configure_test_repository() {
    local repository="$1"
    git -C "$repository" config user.name "Dotfiles Tests"
    git -C "$repository" config user.email "dotfiles-tests@example.com"
    git -C "$repository" config alias.current-branch '!git rev-parse --abbrev-ref HEAD'
    git -C "$repository" config alias.default-branch "!git remote show origin | awk '/HEAD branch/ {print \$NF}'"
}

create_test_repository() {
    mkdir -p "$repository"
    git init -q -b main "$repository"
    configure_test_repository "$repository"
    printf 'original\n' > "$repository/tracked.txt"
    git -C "$repository" add tracked.txt
    git -C "$repository" commit -qm initial
}

given_clean_repository_on_main() {
    repository="${repository:-$fixture/repository}"
    create_test_repository
}

given_repository_on_feature_branch() {
    repository="$fixture/repository"
    create_test_repository
    git -C "$repository" switch -qc feature
}

given_tracked_and_untracked_changes() {
    printf 'changed\n' > "$repository/tracked.txt"
    printf 'untracked\n' > "$repository/untracked.txt"
}

assert_local_changes_are_present() {
    [ "$(cat "$repository/tracked.txt")" = "changed" ]
    [ -f "$repository/untracked.txt" ]
}

given_bare_origin_remote() {
    origin="$fixture/origin.git"
    git init -q --bare "$origin"
    git -C "$repository" remote add origin "$origin"
}

given_unreachable_origin_remote() {
    git -C "$repository" remote add origin "$fixture/missing-origin.git"
}

given_committed_file_change() {
    local path="$1"
    printf 'change on %s\n' "$path" > "$repository/$path"
    git -C "$repository" add "$path"
    git -C "$repository" commit -qm "change $path"
}

assert_success() {
    [ "$status" -eq 0 ]
}

assert_failure() {
    [ "$status" -ne 0 ]
}

assert_status() {
    [ "$status" -eq "$1" ]
}

assert_output_contains() {
    [[ "$output" == *"$1"* ]] || false
}

assert_output_does_not_contain() {
    [[ "$output" != *"$1"* ]] || false
}

assert_output_equals() {
    [ "$output" = "$1" ]
}

assert_path_exists() {
    [ -e "$1" ]
}

assert_path_does_not_exist() {
    [ ! -e "$1" ]
}

assert_file_exists() {
    [ -f "$1" ]
}

assert_file_is_empty() {
    [ ! -s "$1" ]
}

assert_file_content() {
    [ "$(cat -- "$1")" = "$2" ]
}

assert_current_branch() {
    local git_command="${REAL_GIT:-git}"
    [ "$("$git_command" -C "$repository" branch --show-current)" = "$1" ]
}

assert_branch_exists() {
    git -C "$repository" show-ref --verify --quiet "refs/heads/$1"
}

assert_branch_does_not_exist() {
    ! git -C "$repository" show-ref --verify --quiet "refs/heads/$1" || false
}

assert_branch_tracks() {
    [ "$(git -C "$repository" rev-parse --abbrev-ref '@{upstream}')" = "$1" ]
}

assert_remote_branch_does_not_exist() {
    ! git --git-dir="$origin" show-ref --verify --quiet "refs/heads/$1" || false
}

assert_head_is_detached() {
    local git_command="${REAL_GIT:-git}"
    [ -z "$("$git_command" -C "$repository" branch --show-current)" ]
}

assert_worktree_is_clean() {
    local git_command="${REAL_GIT:-git}"
    [ -z "$("$git_command" -C "$repository" status --porcelain)" ]
}

assert_worktree_is_dirty() {
    local git_command="${REAL_GIT:-git}"
    [ -n "$("$git_command" -C "$repository" status --porcelain)" ]
}

assert_stash_is_empty() {
    local git_command="${REAL_GIT:-git}"
    [ -z "$("$git_command" -C "$repository" stash list)" ]
}

assert_stash_count() {
    local git_command="${REAL_GIT:-git}"
    [ "$("$git_command" -C "$repository" stash list | wc -l | tr -d ' ')" -eq "$1" ]
}

assert_stash_contains() {
    local git_command="${REAL_GIT:-git}"
    "$git_command" -C "$repository" stash show --include-untracked --patch stash@{0} | grep -Fq -- "$1"
}
