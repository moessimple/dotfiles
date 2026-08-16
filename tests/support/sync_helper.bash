call_sync() {
    zsh -c 'source "$1"; prune() { return 0; }; cd "$2"; sync' \
        zsh "$dotfiles_dir/support/git/sync.sh" "$repository"
}

call_sync_with_observable_prune() {
    SYNC_PRUNE_LOG="$prune_log" zsh -c \
        'source "$1"; prune() { print pruned > "$SYNC_PRUNE_LOG"; }; cd "$2"; sync' \
        zsh "$dotfiles_dir/support/git/sync.sh" "$repository"
}

given_upstream_main_and_empty_origin() {
    upstream="$fixture/upstream.git"
    origin="$fixture/origin.git"
    git init -q --bare "$upstream"
    git init -q --bare "$origin"
    git -C "$repository" remote add upstream "$upstream"
    git -C "$repository" remote add origin "$origin"
    git -C "$repository" push -q upstream main
    git -C "$repository" fetch -q upstream
}

given_upstream_main_and_unreachable_origin() {
    upstream="$fixture/upstream.git"
    git init -q --bare "$upstream"
    git -C "$repository" remote add upstream "$upstream"
    git -C "$repository" push -q upstream main
    git -C "$repository" fetch -q upstream
    git -C "$repository" remote add origin "$fixture/missing-origin.git"
}

assert_origin_main_matches_upstream() {
    [ "$(git --git-dir="$origin" rev-parse refs/heads/main)" = \
        "$(git --git-dir="$upstream" rev-parse refs/heads/main)" ]
}
