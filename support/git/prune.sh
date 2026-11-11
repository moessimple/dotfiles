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
    # The default branch is compared literally, because a branch name may contain
    # regex characters.
    local merged_branches
    merged_branches=$(git branch --merged origin/$default_branch \
        | grep -E -v "${protected_pattern}" \
        | awk -v branch="$default_branch" '$NF != branch { print $NF }')
    print -r -- "$merged_branches" | xargs git branch -d

    # Delete the remote counterparts of the branches deleted above, and only those, when
    # the remote copy is merged as well. A merged branch that exists only on origin
    # belongs to someone else, such as a colleague's freshly pushed branch on a shared
    # repository, which counts as merged before it has commits of its own.
    local merged_remote_branches branch
    merged_remote_branches=$(git branch -r --merged origin/$default_branch | awk '{ print $NF }')
    for branch in ${(f)merged_branches}; do
        print -r -- "$merged_remote_branches" | grep -qxF "origin/$branch" || continue
        git push origin --delete "$branch" 2>&1 | grep --color=never 'deleted'
    done

    # Delete local branches whose upstream no longer exists.
    git branch --format '%(upstream:track,nobracket)%09%(refname:short)' \
        | grep -E -v "${protected_pattern}" \
        | awk -v branch="$default_branch" '$NF != branch' \
        | awk -F "\t" '{ if($1 ~ /gone/) { print $2 } }' \
        | xargs git branch -D
}
