#!/usr/bin/env bash
# classify.sh - compare each quality-gate path against the kit and print its
# status. Comparison is always against origin/<default-branch>; the project's
# git history is unrelated to the kit's, so there is no before-image to merge.
#
# Usage: classify.sh <profile> <kit_dir> <default-branch> <target>
#   profile          only laravel-starter-kit is supported
#   kit_dir          local kit clone from fetch-kit.sh
#   default-branch   kit default branch
#   target           the project directory
#
# Gate paths come from scripts/gate-paths.txt. Per path, and per deleted-upstream
# candidate the project still carries, prints "<status>\t<path>":
#   new               absent in the project, present at origin/<branch>
#   already-present    byte-identical (cmp -s)
#   differs            present in both, bytes differ
#   deleted-upstream   present in the project, gone from origin/<branch>
#   ungrouped          kit path at the repo root or under .github/ that
#                      gate-paths.txt omits
#
# Exit codes:
#   1   kit_dir has no origin/<branch>
#  64   bad arguments / unknown profile

set -euo pipefail

profile="${1:-}"
kit_dir="${2:-}"
branch="${3:-}"
target="${4:-}"
here="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
gate_list="$here/gate-paths.txt"

if [[ "$profile" != "laravel-starter-kit" || -z "$kit_dir" || -z "$branch" || -z "$target" ]]; then
    echo "Usage: classify.sh laravel-starter-kit <kit_dir> <default-branch> <target>" >&2
    exit 64
fi

if ! git -C "$kit_dir" rev-parse --verify --quiet "origin/$branch" >/dev/null; then
    echo "classify: '$kit_dir' has no origin/$branch (run fetch-kit.sh first)" >&2
    exit 1
fi

# Files the kit dropped in the vite-plus move. Reported only when the project
# still carries them; never enumerated from upstream.
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
"

# Root-level kit files that are NOT quality-gate config: manifests and lockfiles
# (plan-manifest.sh handles those) and paths SKILL.md marks never-write or
# out-of-scope. Any OTHER root-level kit path, and anything under .github/, that
# gate-paths.txt does not list is reported `ungrouped`, so a gate file the kit
# adds later (a new linter, a spell-checker config, a baseline file) is surfaced
# rather than silently skipped. config/ is not scanned: only config/essentials.php
# is in scope, the rest is application config.
root_non_gate="
composer.json composer.lock
package.json package-lock.json pnpm-lock.yaml yarn.lock bun.lock bun.lockb
artisan boost.json
.gitignore .env .env.example .mcp.json
CLAUDE.md README.md README.markdown LICENSE LICENSE.md
"

is_ungrouped_candidate() {
    case "$1" in
        .github/*) return 0 ;;
        */*)       return 1 ;;
    esac
    local skip
    for skip in $root_non_gate; do
        [ "$1" = "$skip" ] && return 1
    done
    return 0
}

classify_one() {
    local path="$1" project_file="$target/$1" upstream
    upstream="$(mktemp "${TMPDIR:-/tmp}/sync-skeleton-blob.XXXXXX")"
    if ! git -C "$kit_dir" show "origin/$branch:$path" >"$upstream" 2>/dev/null; then
        rm -f "$upstream"
        if [[ -e "$project_file" ]]; then
            printf 'deleted-upstream\t%s\n' "$path"
        fi
        return 0
    fi
    if [[ ! -e "$project_file" ]]; then
        printf 'new\t%s\n' "$path"
    elif cmp -s "$upstream" "$project_file"; then
        printf 'already-present\t%s\n' "$path"
    else
        printf 'differs\t%s\n' "$path"
    fi
    rm -f "$upstream"
    return 0
}

gate_paths=""
while IFS= read -r line; do
    line="${line%%#*}"
    line="${line//[[:space:]]/}"
    [ -n "$line" ] || continue
    gate_paths="$gate_paths $line "
    classify_one "$line"
done < "$gate_list"

for path in $deleted_upstream_candidates; do
    [ -e "$target/$path" ] || continue
    git -C "$kit_dir" show "origin/$branch:$path" >/dev/null 2>&1 && continue
    printf 'deleted-upstream\t%s\n' "$path"
done

git -C "$kit_dir" ls-tree -r --name-only "origin/$branch" \
    | while IFS= read -r path; do
        [ -n "$path" ] || continue
        is_ungrouped_candidate "$path" || continue
        case "$gate_paths" in *" $path "*) continue ;; esac
        printf 'ungrouped\t%s\n' "$path"
      done

exit 0
