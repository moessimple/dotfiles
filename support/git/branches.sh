#!/usr/bin/env zsh

# List local branches by recent commit, including upstream information
function gbranches() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: gbranches"
        echo "  Lists local branches sorted by most recent commit, with upstream tracking info."
        return 0
    fi

    local current
    current=$(git current-branch 2>/dev/null)

    git --no-pager for-each-ref \
      --sort=-authordate \
      --format='%(authordate:relative);%(refname:short);%(upstream:short)' \
      refs/heads \
    | while IFS=';' read -r date ref upstream; do
        printf "\033[32m%-24s\033[0m  " "$date"

        if [ "$ref" = "$current" ]; then
            printf "\033[33;1m* %s\033[0m" "$ref"
        else
            printf "\033[33m  %s\033[0m" "$ref"
        fi

        if [ -n "$upstream" ]; then
            printf "  \033[31m→ %s\033[0m" "$upstream"
        fi

        printf "\n"
    done
}
