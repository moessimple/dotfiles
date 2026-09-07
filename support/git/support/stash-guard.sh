#!/usr/bin/env zsh

# Shared by merge, pull and sync: put the working tree aside before a git
# operation that needs a clean tree, then restore it. switch keeps its own
# stash handling because it tags every stash with the branch it belongs to.

# Stashes tracked and untracked changes when the working tree is dirty and
# confirms an entry was actually created: `git stash push` exits 0 even when
# it saves nothing, so a plain exit check would let a caller carry on believing
# the tree is safely put away when it is not. Sets _git_stash_guard_active to 1
# when a stash was pushed and 0 when the tree was already clean; returns
# non-zero, leaving the flag at 0, when stashing was needed but did not happen.
_git_stash_guard() {
    _git_stash_guard_active=0

    [ -n "$(git status --porcelain)" ] || return 0

    local stash_before stash_after
    stash_before=$(git rev-parse -q --verify refs/stash 2>/dev/null)
    git stash push --include-untracked || return
    stash_after=$(git rev-parse -q --verify refs/stash 2>/dev/null)

    if [ -z "$stash_after" ] || [ "$stash_after" = "$stash_before" ]; then
        echo "Could not stash local changes." >&2
        return 1
    fi

    _git_stash_guard_active=1
}

# Restores what _git_stash_guard set aside, if anything. Returns `git stash
# pop`'s exit code so a conflict on restore reaches the caller.
_git_stash_restore() {
    [ "$_git_stash_guard_active" -eq 1 ] || return 0
    git stash pop
}
