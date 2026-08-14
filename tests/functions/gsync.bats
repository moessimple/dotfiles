#!/usr/bin/env bats

load ../support/test_helper

setup() {
    new_git_function_fixture
}

teardown() {
    teardown_dotfiles_fixture
}

@test "gsync restores the starting branch and local changes after a push fails" {
    upstream="$fixture/upstream.git"
    git init -q --bare "$upstream"
    git -C "$repository" remote add upstream "$upstream"
    git -C "$repository" push -q upstream main
    git -C "$repository" fetch -q upstream
    git -C "$repository" remote add origin "$fixture/missing-origin.git"
    make_repository_dirty

    run zsh -c 'source "$1"; gprune() { return 0; }; cd "$2"; gsync' \
        zsh "$dotfiles_dir/support/git/sync.sh" "$repository"

    [ "$status" -ne 0 ]
    [ "$(git -C "$repository" branch --show-current)" = "feature" ]
    [ "$(cat "$repository/tracked.txt")" = "changed" ]
    [ -f "$repository/untracked.txt" ]
    [ -z "$(git -C "$repository" stash list)" ]
}

@test "gsync updates origin main to match upstream" {
    new_sync_remotes

    run zsh -c 'source "$1"; gprune() { return 0; }; cd "$2"; gsync' \
        zsh "$dotfiles_dir/support/git/sync.sh" "$repository"

    [ "$status" -eq 0 ]
    [ "$(git --git-dir="$origin" rev-parse refs/heads/main)" = "$(git --git-dir="$upstream" rev-parse refs/heads/main)" ]
}

@test "gsync restores the starting branch and local changes after a successful sync" {
    new_sync_remotes
    make_repository_dirty

    run zsh -c 'source "$1"; gprune() { return 0; }; cd "$2"; gsync' \
        zsh "$dotfiles_dir/support/git/sync.sh" "$repository"

    [ "$status" -eq 0 ]
    [ "$(git -C "$repository" branch --show-current)" = "feature" ]
    [ "$(cat "$repository/tracked.txt")" = "changed" ]
    [ -f "$repository/untracked.txt" ]
    [ -z "$(git -C "$repository" stash list)" ]
}

@test "gsync prunes branches after a successful sync" {
    new_sync_remotes
    prune_log="$fixture/prune.log"

    run env GSYNC_PRUNE_LOG="$prune_log" zsh -c \
        'source "$1"; gprune() { print pruned > "$GSYNC_PRUNE_LOG"; }; cd "$2"; gsync' \
        zsh "$dotfiles_dir/support/git/sync.sh" "$repository"

    [ "$status" -eq 0 ]
    [ -f "$prune_log" ]
}

new_sync_remotes() {
    upstream="$fixture/upstream.git"
    origin="$fixture/origin.git"
    git init -q --bare "$upstream"
    git init -q --bare "$origin"
    git -C "$repository" remote add upstream "$upstream"
    git -C "$repository" remote add origin "$origin"
    git -C "$repository" push -q upstream main
    git -C "$repository" fetch -q upstream
}
