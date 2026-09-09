#!/usr/bin/env zsh

# Search git history for commits that introduced or removed a string (pickaxe search)
_SEARCH_DIR="${0:A:h}"

function search() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: search <term>"
        echo "  term  String or regex to search for in git history"
        echo "  Shows only the diff hunks that contain the search term (case-insensitive)."
        return 0
    fi

    test -z "$1" && echo "search term required" 1>&2 && return 1

    # Passed to git as a one-shot environment entry, not exported into the shell:
    # git forwards its environment to the diff.external driver, which reads
    # GREPDIFF_REGEX, but nothing after this call should see it.
    GREPDIFF_REGEX="$1" git -c core.pager="less -RFX" -c diff.external="$_SEARCH_DIR/support/pickaxe-diff.sh" log -p --ext-diff --regexp-ignore-case -S"$1" -- . ":(exclude)phpstan-baseline.neon" ":(exclude)phparkitect-baseline.json"
}
