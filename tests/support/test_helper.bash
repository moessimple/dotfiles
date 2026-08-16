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
}

create_test_repository() {
    mkdir -p "$repository"
    git init -q -b main "$repository"
    configure_test_repository "$repository"
    printf 'original\n' > "$repository/tracked.txt"
    git -C "$repository" add tracked.txt
    git -C "$repository" commit -qm initial
}

new_git_function_fixture() {
    new_dotfiles_fixture
    repository="$fixture/repository"
    create_test_repository
    git -C "$repository" switch -qc feature
}

make_repository_dirty() {
    printf 'changed\n' > "$repository/tracked.txt"
    printf 'untracked\n' > "$repository/untracked.txt"
}

assert_success() {
    [ "$status" -eq 0 ]
}

assert_failure() {
    [ "$status" -ne 0 ]
}

assert_output_contains() {
    [[ "$output" == *"$1"* ]] || false
}

assert_current_branch() {
    local git_command="${REAL_GIT:-git}"
    [ "$("$git_command" -C "$repository" branch --show-current)" = "$1" ]
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
