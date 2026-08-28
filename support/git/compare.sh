#!/usr/bin/env zsh

# Browse and diff branches against a base branch interactively via fzf
function compare() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: compare [base]"
        echo "  base  Branch to compare against (default: default branch)"
        return 0
    fi

    local base branch
    base="${1:-$(git default-branch)}"

    branch=$(git for-each-ref \
        --sort=-authordate \
        --format='%(refname:short)' \
        refs/heads \
        | grep -v "^${base}$" \
        | fzf \
            --no-sort \
            --preview "git diff --color=always ${base}...{}" \
            --preview-window=right:65%:wrap \
            --height=90% \
            --header="compare vs ${base} — Enter: full diff"
    )

    [ -n "$branch" ] && git diff "${base}...${branch}"
}
