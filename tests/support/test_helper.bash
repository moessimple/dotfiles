new_dotfiles_fixture() {
    dotfiles_dir="$(cd "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
    functions_file="$dotfiles_dir/home/.functions"
    fixture="$BATS_TEST_TMPDIR/dotfiles-fixture"
    mkdir -p "$fixture"
}

teardown_dotfiles_fixture() {
    rm -rf -- "$fixture"
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
