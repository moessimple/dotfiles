#!/usr/bin/env zsh

# Review changed files in the current branch against a base branch via fzf
function greview() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: greview [base]"
        echo "  base  Branch to compare against (default: default branch)"
        return 0
    fi

    local base="${1:-$(git default-branch)}"

    git diff --name-only "${base}...HEAD" \
        | fzf \
            --no-sort \
            --preview "git diff --color=always ${base}...HEAD -- {}" \
            --preview-window=right:65%:wrap \
            --height=90% \
            --header="changed files vs ${base} — Enter: open in editor" \
            --bind "enter:execute(code --goto {})"
}
