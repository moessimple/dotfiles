#!/bin/bash
# Traces every line a change removes or replaces to the commit that last touched it, and that
# commit to the GitHub pull request it came from, grouped by commit.
#
# Usage: history.sh <base> [<head>]
#   Run inside the repository. With <head>, traces <base>...<head> (a PR). Without it, traces
#   the working tree, uncommitted changes included, against the merge base of <base> and HEAD.

set -euo pipefail

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "usage: history.sh <base> [<head>]" >&2
    exit 64
fi

base="$1"
head="${2:-}"

# Removed lines are blamed at the merge base, not at <base>: once the base branch has moved on,
# its tip may already have changed or dropped the very lines the change removes.
merge_base=$(git merge-base "$base" "${head:-HEAD}")

if [ -n "$head" ]; then
    diff_range=("$merge_base" "$head")
else
    diff_range=("$merge_base")
fi

removed_ranges() {
    local path start end
    # Read literal filenames, not the C-quoted paths in patch headers. Treat renames as
    # deletion/addition so blame always uses the path that exists at the merge base.
    git diff --no-renames --name-only -z --no-ext-diff "${diff_range[@]}" |
        while IFS= read -r -d '' path; do
            case "$path" in
                *$'\t'*|*$'\n'*)
                    echo "history: filenames containing tabs or newlines are not supported" >&2
                    return 1
                    ;;
            esac
            git diff -U0 --no-renames --no-color --no-ext-diff --no-textconv \
                "${diff_range[@]}" -- "$path" |
                awk '/^@@ / {
                    split($2, old, ",")
                    start = substr(old[1], 2)
                    count = (old[2] == "") ? 1 : old[2]
                    if (count > 0) printf "%d\t%d\n", start, start + count - 1
                }' |
                while IFS=$'\t' read -r start end; do
                    printf '%s\t%s\t%s\n' "$path" "$start" "$end"
                done
        done
}

# One "<sha> <path> <line>" row per removed line, line numbers as they are at the merge base.
blamed_lines() {
    local path start end
    while IFS=$'\t' read -r path start end; do
        git blame -w --porcelain -L "$start,$end" "$merge_base" -- "$path" |
            HISTORY_PATH="$path" awk '
                length($1) == 40 && $1 ~ /^[0-9a-f]+$/ && $3 ~ /^[0-9]+$/ {
                    printf "%s\t%s\t%d\n", $1, ENVIRON["HISTORY_PATH"], $3
                }'
    done
}

# One "<sha> <path>:<a>-<b>, ..." row per commit, consecutive lines folded into ranges.
lines_by_commit() {
    sort -t $'\t' -k1,1 -k2,2 -k3,3n | awk -F '\t' '
        function close_range() {
            if (from == "") return
            ranges[sha] = ranges[sha] (ranges[sha] == "" ? "" : ", ") file ":" (from == to ? from : from "-" to)
        }
        $1 != sha || $2 != file || $3 != to + 1 {
            close_range()
            if ($1 != sha) order[++count] = $1
            sha = $1; file = $2; from = $3
        }
        { to = $3 }
        END {
            close_range()
            for (i = 1; i <= count; i++) printf "%s\t%s\n", order[i], ranges[order[i]]
        }'
}

github_repository() {
    local url
    url=$(git remote get-url origin 2>/dev/null) || return 0
    printf '%s\n' "$url" |
        sed -nE 's#^(https://github\.com/|git@github\.com:|ssh://git@github\.com/)([^/]+/[^/]+)$#\2#p' |
        sed 's/\.git$//'
}

indent() {
    sed 's/^/    /'
}

describe_commit() {
    local sha="$1" lines="$2" repository="$3" pulls

    printf '== %s\n' "$(git show -s --format='%h %as %s' "$sha")"
    printf 'lines: %s\n' "$lines"

    if [ -z "$repository" ]; then
        echo "pr: not looked up, origin is not a GitHub repository"
    elif ! pulls=$(gh api "repos/$repository/commits/$sha/pulls" 2>/dev/null); then
        echo "pr: lookup failed (gh api)"
    elif [ "$(jq 'length' <<< "$pulls")" -gt 0 ]; then
        jq -r '.[0] | "pr: #\(.number) \(.title)\nurl: \(.html_url)\n"' <<< "$pulls"
        jq -r '.[0].body // ""' <<< "$pulls" | indent
        echo
        return
    else
        echo "pr: none"
    fi

    echo
    git show -s --format='%B' "$sha" | indent
}

ranges=$(removed_ranges)

if [ -z "$ranges" ]; then
    echo "No removed or replaced lines: the change only adds code."
    exit 0
fi

repository=$(github_repository)
commits=$(blamed_lines <<< "$ranges" | lines_by_commit)

while IFS=$'\t' read -r sha lines; do
    describe_commit "$sha" "$lines" "$repository"
done <<< "$commits"
