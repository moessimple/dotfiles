call_sync() {
    zsh -c 'source "$1"; prune() { return 0; }; cd "$2"; sync "${@:3}"' \
        zsh "$dotfiles_dir/support/git/sync.sh" "$repository" "$@"
}

call_sync_with_observable_prune() {
    SYNC_PRUNE_LOG="$prune_log" zsh -c \
        'source "$1"; prune() { print pruned > "$SYNC_PRUNE_LOG"; }; cd "$2"; sync' \
        zsh "$dotfiles_dir/support/git/sync.sh" "$repository"
}

call_sync_with_failing_tag_push() {
    zsh -c '
        function git() {
            if [[ "$1" == "push" && "$2" == "origin" && "$3" == "--tags" ]]; then
                echo "simulated tag push failure" >&2
                return 17
            fi
            command git "$@"
        }
        source "$1"
        prune() { return 0; }
        cd "$2"
        sync
    ' zsh "$dotfiles_dir/support/git/sync.sh" "$repository"
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

given_upstream_develop_only_and_empty_origin() {
    upstream="$fixture/upstream.git"
    origin="$fixture/origin.git"
    git init -q --bare "$upstream"
    git init -q --bare "$origin"
    git -C "$repository" remote add upstream "$upstream"
    git -C "$repository" remote add origin "$origin"
    git -C "$repository" branch develop main
    git -C "$repository" push -q upstream develop
    git -C "$repository" branch -D develop
    git -C "$repository" fetch -q upstream
}

given_upstream_main_and_develop_and_empty_origin() {
    given_upstream_main_and_empty_origin
    git -C "$repository" branch develop main
    git -C "$repository" push -q upstream develop
}

assert_origin_branch_matches_upstream() {
    local branch="$1"
    [ "$(git --git-dir="$origin" rev-parse "refs/heads/$branch")" = \
        "$(git --git-dir="$upstream" rev-parse "refs/heads/$branch")" ]
}
