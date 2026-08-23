#!/usr/bin/env zsh

# The uncommitted-changes handling below (bring/leave/cancel, warn before overwriting a
# leftover stash) is adapted from GitHub Desktop's branch-switch workflow, reimplemented
# independently rather than sharing any format or code with the app itself.

# Marks a stash with the branch it belongs to, so a stash left behind on a branch by switch's
# "leave" choice is found again the next time that branch comes up here.
_switch_stash_marker() {
    echo "!!dotfiles-switch<$1>"
}

# Finds the newest stash entry marked for $1, if any. The marker is matched as a suffix, not
# an exact match, since `git stash push -m` prepends "On <branch>: " to the message.
_switch_find_stash() {
    local marker="$(_switch_stash_marker "$1")" line ref message
    while IFS= read -r line; do
        ref="${line%%:*}"
        message="${line#*: }"
        if [[ "$message" == *"$marker" ]]; then
            echo "$ref"
            return 0
        fi
    done < <(git stash list)
    return 1
}

# Confirms something was actually saved, since `git stash push` exits 0 even when there
# was nothing to stash.
_switch_do_stash() {
    local message="$1" stash_before stash_after
    stash_before=$(git rev-parse -q --verify refs/stash 2>/dev/null)
    git stash push --include-untracked -m "$message"
    local push_status=$?
    [ "$push_status" -eq 0 ] || return "$push_status"

    stash_after=$(git rev-parse -q --verify refs/stash 2>/dev/null)
    if [ -z "$stash_after" ] || [ "$stash_after" = "$stash_before" ]; then
        echo "Could not stash local changes; branch was not switched." >&2
        return 1
    fi
    return 0
}

# Switch to a branch (creating it if needed). With uncommitted changes, asks whether to bring
# them along, leave them stashed on the current branch, or cancel, and warns before
# overwriting a stash already left on the current branch.
function switch() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: switch <branch>"
        echo "  branch  Branch to switch to (created automatically if it does not exist)"
        echo "  With uncommitted changes, asks whether to bring them along, leave them"
        echo "  stashed on the current branch, or cancel — like GitHub Desktop."
        return 0
    fi

    [ $# -eq 0 ] && { echo "No branch name given."; return 1; }
    [ $# -ne 1 ] && { echo "Expected exactly one branch name."; return 1; }

    local requested_branch="$1" branch
    branch=$(git check-ref-format --branch "$requested_branch" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "Invalid branch name: $requested_branch" >&2
        return 1
    fi

    local current_branch
    current_branch=$(git symbolic-ref --quiet --short HEAD) || current_branch=$(git rev-parse --short HEAD) || return

    local stashed=0 leaving=0 exit_code status_output remote_branches
    status_output=$(git status --porcelain) || return
    if [ -n "$status_output" ]; then
        echo "You have changes on this branch. What would you like to do with them?"
        echo "  1) Leave my changes on $current_branch"
        echo "     Your in-progress work will be stashed on this branch for you to return to later"
        echo "  2) Bring my changes to $branch"
        echo "     Your in-progress work will follow you to the new branch"
        echo "  3) Cancel"

        local choice
        read -r "choice?Choice: "

        case "$choice" in
            1)
                if [ -n "$(_switch_find_stash "$current_branch")" ]; then
                    if ! read -q "?Overwrite the existing stash on $current_branch with your current changes? [y/N] "; then
                        echo
                        echo "Switch cancelled."
                        return 1
                    fi
                    echo
                fi
                _switch_do_stash "$(_switch_stash_marker "$current_branch")" || return
                stashed=1
                leaving=1
                ;;
            2)
                _switch_do_stash "$(_switch_stash_marker "$current_branch")" || return
                stashed=1
                ;;
            *)
                echo "Switch cancelled."
                return 1
                ;;
        esac
    fi

    if git show-ref --verify --quiet "refs/heads/$branch"; then
        git switch "$branch"
    else
        remote_branches=$(git for-each-ref --format='%(refname)' "refs/remotes/*/$branch") || return
        if [ -n "$remote_branches" ]; then
            git switch "$branch"
        else
            git switch -c "$branch"
        fi
    fi
    exit_code=$?

    if [ "$exit_code" -ne 0 ]; then
        [ "$stashed" -eq 1 ] && echo "Switch failed; your changes remain in the stash." >&2
        return "$exit_code"
    fi

    if [ "$stashed" -eq 1 ] && [ "$leaving" -eq 0 ]; then
        git stash pop --index
        exit_code=$?
        [ "$exit_code" -eq 0 ] || return "$exit_code"
    fi

    if [ -n "$(_switch_find_stash "$branch")" ]; then
        echo "Stashed changes are available on this branch. Run 'git stash pop' to restore them."
    fi

    return 0
}
