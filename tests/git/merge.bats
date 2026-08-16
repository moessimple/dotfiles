#!/usr/bin/env bats

load ../support/test_helper

setup() {
    new_git_function_fixture
}

teardown() {
    teardown_dotfiles_fixture
}

@test "merge leaves local changes stashed when the merge fails" {
    make_repository_dirty

    run zsh -c 'source "$1"; cd "$2"; merge missing-branch' \
        zsh "$dotfiles_dir/support/git/merge.sh" "$repository"

    [ "$status" -ne 0 ]
    [ "$(git -C "$repository" branch --show-current)" = "feature" ]
    [ -z "$(git -C "$repository" status --porcelain)" ]
    [ "$(git -C "$repository" stash list | wc -l | tr -d ' ')" -eq 1 ]
    [[ "$output" == *'changes remain in the stash'* ]]
}

@test "merge brings changes from the selected branch into the current branch" {
    git -C "$repository" switch -q main
    printf 'from main\n' > "$repository/from-main.txt"
    git -C "$repository" add from-main.txt
    git -C "$repository" commit -qm "change on main"
    git -C "$repository" switch -q feature

    run zsh -c 'source "$1"; cd "$2"; merge main' \
        zsh "$dotfiles_dir/support/git/merge.sh" "$repository"

    [ "$status" -eq 0 ]
    [ "$(cat "$repository/from-main.txt")" = "from main" ]
}
