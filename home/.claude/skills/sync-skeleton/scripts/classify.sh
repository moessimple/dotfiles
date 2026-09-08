#!/usr/bin/env bash
# classify.sh - compare every tracked starter-kit path against the target project
# and print one classification line per path.
#
# Usage: classify.sh <profile> <kit_dir> <default-branch> <target>
#   profile          skeleton profile (only laravel-starter-kit is supported)
#   kit_dir          local kit clone from fetch-kit.sh
#   default-branch   kit default branch; comparison is always against origin/<it>
#   target           the project directory
#
# Output, tab-separated, one line per path:
#   <status>\t<bucket>\t<path>
# The bucket column is the literal "TODO" until Slice 4 fills it in.
#
# Statuses:
#   new               absent in the project, present at origin/<branch>
#   identical         byte-equal (cmp -s)
#   differs           present in both, text, bytes differ
#   differs-binary    present in both, binary, bytes differ
#   deleted-upstream  present in the project, gone from origin/<branch>
#   manifest          composer/package manifest or lockfile (always user-mediated)
#
# Comparison is byte-exact via cmp -s against `git show origin/<branch>:<path>`,
# never against the kit worktree and never via diff.
#
# Exit codes:
#   1   kit_dir has no origin/<branch>
#  64   bad arguments / unknown profile

set -euo pipefail

profile="${1:-}"
kit_dir="${2:-}"
branch="${3:-}"
target="${4:-}"

if [[ "$profile" != "laravel-starter-kit" || -z "$kit_dir" || -z "$branch" || -z "$target" ]]; then
    echo "Usage: classify.sh laravel-starter-kit <kit_dir> <default-branch> <target>" >&2
    exit 64
fi

if ! git -C "$kit_dir" rev-parse --verify --quiet "origin/$branch" >/dev/null; then
    echo "classify: '$kit_dir' has no origin/$branch (run fetch-kit.sh first)" >&2
    exit 1
fi

# Paths the kit removed in the vite-plus / strict-suite cleanup. Reported only
# when the project still carries them; they are never enumerated from upstream.
deleted_upstream_candidates="
eslint.config.js
eslint.config.mjs
eslint.config.cjs
eslint.config.ts
.prettierrc
.prettierrc.json
.prettierrc.js
.prettierrc.cjs
.prettierrc.yml
.prettierrc.yaml
.prettierignore
resources/js/lib/utils.ts
tests/Feature/ExampleTest.php
tests/Unit/ExampleTest.php
"

is_manifest() {
    case "$1" in
        composer.json|package.json|composer.lock|pnpm-lock.yaml|*-lock.*) return 0 ;;
        *) return 1 ;;
    esac
}

is_binary() {
    [ -s "$1" ] || return 1
    [ "$(file --mime-encoding -b -- "$1")" = "binary" ]
}

classify_path() {
    local path="$1"
    local project_file="$target/$path"

    if is_manifest "$path"; then
        printf 'manifest\tTODO\t%s\n' "$path"
        return
    fi

    local upstream
    upstream="$(mktemp "${TMPDIR:-/tmp}/sync-skeleton-blob.XXXXXX")"
    if ! git -C "$kit_dir" show "origin/$branch:$path" >"$upstream" 2>/dev/null; then
        rm -f "$upstream"
        return
    fi

    if [[ ! -e "$project_file" ]]; then
        printf 'new\tTODO\t%s\n' "$path"
    elif cmp -s "$upstream" "$project_file"; then
        printf 'identical\tTODO\t%s\n' "$path"
    elif is_binary "$upstream" || is_binary "$project_file"; then
        printf 'differs-binary\tTODO\t%s\n' "$path"
    else
        printf 'differs\tTODO\t%s\n' "$path"
    fi

    rm -f "$upstream"
}

git -C "$kit_dir" ls-tree -r --name-only "origin/$branch" \
    | while IFS= read -r path; do
        [ -n "$path" ] || continue
        classify_path "$path"
      done

for path in $deleted_upstream_candidates; do
    [ -e "$target/$path" ] || continue
    git -C "$kit_dir" show "origin/$branch:$path" >/dev/null 2>&1 && continue
    printf 'deleted-upstream\tTODO\t%s\n' "$path"
done
