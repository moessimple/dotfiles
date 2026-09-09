#!/usr/bin/env zsh

source "${0:A:h}/support/long-lived-branches.sh"

# Delete local and remote branches that have been merged or whose remote is gone
function prune() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: prune"
        echo "  Prunes stale remote-tracking branches, deletes local branches merged into"
        echo "  the default branch, removes their remote counterparts, and deletes squashed branches."
        echo "  Protected branches (main, master, develop, release) are never deleted."
        return 0
    fi

    # Whole-name match only, so "feature/domain-model" or "premaster" don't count.
    local protected_pattern="(^\*|(^|[[:space:]/])(${(j:|:)long_lived_branches})\$)"
    local default_branch
    # Both preconditions are guarded: prune deletes local and remote branches, so a
    # failed default-branch resolution or a failed fetch must stop it rather than let
    # it act on a stale or wrong merge base.
    default_branch=$(git default-branch) || return

    # Prune obsolete remote-tracking branches: branches we once tracked that have since
    # been deleted on the remote.
    git fetch origin --prune --jobs=10 || return

    # List all local branches merged fully into the default branch, then delete them.
    # Merged against origin/$default_branch, not the local branch, so a stale local
    # default branch doesn't leave branches merged upstream undetected.
    git branch --merged origin/$default_branch \
        | grep -E -v "${protected_pattern}" \
        | xargs git branch -d

    # Delete remote branches fully merged into the remote default branch.
    git branch -r --merged origin/$default_branch \
        | grep -E -v "${protected_pattern}" \
        | grep origin/ \
        | cut -d"/" -f2- \
        | xargs -I% git push origin :% 2>&1 \
        | grep --color=never 'deleted'

    # Delete local branches whose upstream no longer exists.
    git branch --format '%(upstream:track,nobracket)%09%(refname:short)' \
        | grep -E -v "${protected_pattern}" \
        | awk -F "\t" '{ if($1 ~ /gone/) { print $2 } }' \
        | xargs git branch -D
}
