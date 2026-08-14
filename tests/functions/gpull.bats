#!/usr/bin/env bats

load ../support/test_helper

setup() {
    new_git_function_fixture
}

teardown() {
    teardown_dotfiles_fixture
}

@test "gpull leaves local changes stashed when the pull fails" {
    make_repository_dirty
    git -C "$repository" remote add origin "$fixture/missing-origin.git"

    run zsh -c 'source "$1"; cd "$2"; gpull' \
        zsh "$dotfiles_dir/support/git/pull.sh" "$repository"

    [ "$status" -ne 0 ]
    [ "$(git -C "$repository" branch --show-current)" = "feature" ]
    [ -z "$(git -C "$repository" status --porcelain)" ]
    [ "$(git -C "$repository" stash list | wc -l | tr -d ' ')" -eq 1 ]
    [[ "$output" == *'changes remain in the stash'* ]]
}

@test "gpull brings remote changes into the current branch" {
    origin="$fixture/origin.git"
    git init -q --bare "$origin"
    git -C "$repository" remote add origin "$origin"
    git -C "$repository" push -qu origin feature
    previous_commit="$(git -C "$repository" rev-parse HEAD)"
    printf 'from origin\n' > "$repository/from-origin.txt"
    git -C "$repository" add from-origin.txt
    git -C "$repository" commit -qm "change on origin"
    git -C "$repository" push -q origin feature
    git -C "$repository" reset -q --hard "$previous_commit"

    run zsh -c 'source "$1"; cd "$2"; gpull' \
        zsh "$dotfiles_dir/support/git/pull.sh" "$repository"

    [ "$status" -eq 0 ]
    [ "$(cat "$repository/from-origin.txt")" = "from origin" ]
}
