#!/usr/bin/env zsh

source "${0:A:h}/support/long-lived-branches.sh"

# Delete local and remote branches that have been merged or whose remote is gone
function prune() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: prune"
        echo "  Prunes stale remote-tracking branches, deletes local branches merged into"
        echo "  the default branch, removes their remote counterparts, and deletes squashed branches."
        echo "  The default branch and the long-lived branches (main, master, develop, release)"
        echo "  are never deleted."
        return 0
    fi

    # Whole-name match only, so "feature/domain-model" or "premaster" don't count.
    local protected_pattern="(^\*|(^|[[:space:]/])(${(j:|:)long_lived_branches})\$)"
    local default_branch current_branch
    # Both preconditions are guarded: prune deletes local and remote branches, so a
    # failed default-branch resolution or a failed fetch must stop it rather than let
    # it act on a stale or wrong merge base.
    default_branch=$(git default-branch) || return

    # Prune obsolete remote-tracking branches: branches we once tracked that have since
    # been deleted on the remote.
    git fetch origin --prune --jobs=10 || return
    current_branch=$(git branch --show-current)

    # List all local branches merged fully into the default branch, then delete them.
    # Merged against origin/$default_branch, not the local branch, so a stale local
    # default branch doesn't leave branches merged upstream undetected.
    # The default branch is compared literally, not added to protected_pattern,
    # because a branch name may contain regex characters.
    git branch --merged origin/$default_branch \
        | grep -E -v "${protected_pattern}" \
        | awk -v branch="$default_branch" '$NF != branch' \
        | xargs git branch -d

    # Delete remote branches fully merged into the remote default branch. The
    # checked-out branch keeps its remote copy: a freshly pushed branch without
    # commits of its own counts as merged, and deleting it would close its open PR.
    git branch -r --merged origin/$default_branch \
        | grep -E -v "${protected_pattern}" \
        | awk -v branch="origin/$default_branch" -v current="origin/$current_branch" \
            '$NF != branch && $NF != current' \
        | grep origin/ \
        | cut -d"/" -f2- \
        | xargs -I% git push origin :% 2>&1 \
        | grep --color=never 'deleted'

    # Delete local branches whose upstream no longer exists.
    git branch --format '%(upstream:track,nobracket)%09%(refname:short)' \
        | grep -E -v "${protected_pattern}" \
        | awk -v branch="$default_branch" '$NF != branch' \
        | awk -F "\t" '{ if($1 ~ /gone/) { print $2 } }' \
        | xargs git branch -D
}
