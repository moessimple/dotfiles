#!/usr/bin/env zsh

# Abort an in-progress rebase, merge, cherry-pick, revert, or bisect, then
# reset to HEAD and remove untracked files
function nah() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: nah"
        echo "  Aborts any in-progress rebase, merge, cherry-pick, revert, or bisect,"
        echo "  then hard resets to HEAD and removes untracked files."
        return 0
    fi

    local git_path=$(git rev-parse --git-dir)

    if [ -d "${git_path}/rebase-merge" ]; then
        git rebase --abort
    elif [ -d "${git_path}/rebase-apply" ]; then
        git rebase --abort
    elif [ -f "${git_path}/MERGE_HEAD" ]; then
        git merge --abort
    elif [ -f "${git_path}/CHERRY_PICK_HEAD" ]; then
        git cherry-pick --abort
    elif [ -f "${git_path}/REVERT_HEAD" ]; then
        git revert --abort
    elif [ -d "${git_path}/bisect" ]; then
        git bisect reset
    fi

    git reset --hard && git clean -df;
}
