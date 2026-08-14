new_dotfiles_fixture() {
    dotfiles_dir="$(cd "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
    functions_file="$dotfiles_dir/home/.functions"
    fixture="$(mktemp -d)"
}

teardown_dotfiles_fixture() {
    rm -rf -- "$fixture"
}

configure_test_repository() {
    local repository="$1"
    git -C "$repository" config user.name "Dotfiles Tests"
    git -C "$repository" config user.email "dotfiles-tests@example.com"
}

new_git_function_fixture() {
    new_dotfiles_fixture
    repository="$fixture/repository"
    mkdir -p "$repository"
    git init -q -b main "$repository"
    configure_test_repository "$repository"
    printf 'original\n' > "$repository/tracked.txt"
    git -C "$repository" add tracked.txt
    git -C "$repository" commit -qm initial
    git -C "$repository" switch -qc feature
}

make_repository_dirty() {
    printf 'changed\n' > "$repository/tracked.txt"
    printf 'untracked\n' > "$repository/untracked.txt"
}
