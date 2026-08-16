#!/usr/bin/env zsh

# Delete local and remote branches that have been merged or whose remote is gone
function prune() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: prune"
        echo "  Prunes stale remote-tracking branches, deletes local branches merged into"
        echo "  the default branch, removes their remote counterparts, and deletes squashed branches."
        echo "  Protected branches (main, master, develop, release) are never deleted."
        return 0
    fi

    # Match only whole branch names, not any name containing these words as a substring
    # (e.g. "feature/domain-model" or "premaster" must not count as protected).
    local protected_branches="(^\*|(^|[[:space:]/])(develop|master|main|release)\$)"
    local default_branch
    default_branch=$(git default-branch)

    # Prune obsolete remote-tracking branches: branches we once tracked that have since
    # been deleted on the remote.
    git fetch origin --prune --jobs=10

    # List all local branches merged fully into the default branch, then delete them.
    # Merged against origin/$default_branch, not the local branch, so a stale local
    # default branch doesn't leave branches merged upstream undetected.
    git branch --merged origin/$default_branch \
        | grep -E -v "${protected_branches}" \
        | xargs git branch -d

    # Delete remote branches fully merged into the remote default branch.
    git branch -r --merged origin/$default_branch \
        | grep -E -v "${protected_branches}" \
        | grep origin/ \
        | cut -d"/" -f2- \
        | xargs -I% git push origin :% 2>&1 \
        | grep --color=never 'deleted'

    # Delete local branches whose upstream no longer exists.
    git branch --format '%(upstream:track,nobracket)%09%(refname:short)' \
        | grep -E -v "${protected_branches}" \
        | awk -F "\t" '{ if($1 ~ /gone/) { print $2 } }' \
        | xargs git branch -D
}
