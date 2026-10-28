#!/usr/bin/env zsh

# Review changed files in the current branch against a base branch via fzf,
# including uncommitted and untracked changes in the working tree
function review() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: review [base]"
        echo "  base  Branch to compare against (default: default branch)"
        echo "        Compares the working tree, so uncommitted changes are included"
        return 0
    fi

    local base="${1:-$(git default-branch)}"

    # Untracked files are unknown to `git diff`, so they are listed separately
    # and previewed as new files.
    {
        git diff --name-only --merge-base "$base"
        git ls-files --others --exclude-standard
    } \
        | fzf \
            --no-sort \
            --preview "if [ -n \"\$(git ls-files --others --exclude-standard -- {})\" ]; then \
                    git diff --color=always --no-index /dev/null {}; \
                else \
                    git diff --color=always --merge-base ${base} -- {}; \
                fi" \
            --preview-window=right:65%:wrap \
            --height=90% \
            --header="changed files vs ${base}, including uncommitted — Enter: open in editor" \
            --bind "enter:execute(code --goto {})"
}
