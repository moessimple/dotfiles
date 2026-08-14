#!/usr/bin/env bats

load ../support/test_helper

setup() {
    new_dotfiles_fixture
}

teardown() {
    teardown_dotfiles_fixture
}

@test "commit stages changes across the entire repository from a nested directory" {
    repository="$fixture/repository"
    mkdir -p "$repository/nested"
    git init -q -b main "$repository"
    configure_test_repository "$repository"
    printf 'original\n' > "$repository/sibling.txt"
    printf 'remove me\n' > "$repository/nested/removed.txt"
    git -C "$repository" add --all
    git -C "$repository" commit -qm initial

    printf 'changed\n' > "$repository/sibling.txt"
    rm "$repository/nested/removed.txt"
    printf 'new\n' > "$repository/new-root.txt"

    run zsh -c 'source "$1"; cd "$2/nested"; commit "stage every path"' zsh "$functions_file" "$repository"

    [ "$status" -eq 0 ]
    [ -z "$(git -C "$repository" status --porcelain)" ]
    changes="$(git -C "$repository" show --format= --name-status HEAD)"
    [[ "$changes" == *$'A\tnew-root.txt'* ]]
    [[ "$changes" == *$'D\tnested/removed.txt'* ]]
    [[ "$changes" == *$'M\tsibling.txt'* ]]
}
