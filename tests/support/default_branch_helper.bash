call_default_branch() {
    (cd "$repository" && sh "$dotfiles_dir/home/.config/git/default-branch")
}

# Publishes $branch to a bare origin remote and points that remote's own HEAD
# at it, so `git ls-remote --symref origin HEAD` resolves live.
given_origin_default_branch() {
    local branch="$1"
    given_bare_origin_remote
    git -C "$repository" push -q origin "$branch"
    git --git-dir="$origin" symbolic-ref HEAD "refs/heads/$branch"
}

# Same as given_origin_default_branch but for an `upstream` remote, used to
# check that a fork clone's upstream outranks its origin.
given_upstream_default_branch() {
    local branch="$1"
    local upstream="$fixture/upstream.git"
    git init -q --bare "$upstream"
    git -C "$repository" remote add upstream "$upstream"
    git -C "$repository" push -q upstream "$branch"
    git --git-dir="$upstream" symbolic-ref HEAD "refs/heads/$branch"
}

# Sets only the local remote-tracking cache, without a reachable remote, so the
# resolver's offline fallback tier can be exercised in isolation.
given_cached_origin_default_branch() {
    git -C "$repository" symbolic-ref refs/remotes/origin/HEAD "refs/remotes/origin/$1"
}

given_branch() {
    git -C "$repository" branch -q "$1"
}

given_no_main_or_master_branch() {
    git -C "$repository" branch -qm main other
}
