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
# where <bucket> is one of the curated theme buckets, never-touch, drift-only, or
# not-in-scope (see reference/profiles/laravel-starter-kit.md; buckets.bats keeps
# the two in sync).
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

# Map a kit path to its theme bucket. Priority order matches the catalog in
# reference/profiles/laravel-starter-kit.md; the first matching arm wins.
bucket_for() {
    case "$1" in
        .github/*|pint.json|phpstan.neon|rector.php|phpunit.xml|.gitattributes|composer.json|composer.lock)
            echo quality-gate ;;
        vite.config.ts|vitest.config.ts|vitest.setup.ts|tsconfig.json|.npmrc|.nvmrc|pnpm-workspace.yaml|package.json|package-lock.json|pnpm-lock.yaml)
            echo frontend-tooling ;;
        eslint.config.*|.prettierrc*|.prettierignore|resources/js/lib/utils.ts)
            echo frontend-tooling ;;
        config/essentials.php)
            echo essentials ;;
        tests/Arch/*|tests/ArchTest.php|tests/Http/*|tests/Console/.gitkeep|tests/Unit/*/.gitkeep|tests/Feature/ExampleTest.php|tests/Unit/ExampleTest.php)
            echo arch-tests ;;
        resources/js/pages/Welcome.test.ts)
            echo frontend-test-setup ;;
        .ai/rules/*|.claude/skills/*|.mcp.json|boost.json)
            echo agent-rules ;;
        resources/js/pages/Welcome.vue|resources/views/app.blade.php|resources/css/app.css)
            echo welcome-page ;;
        config/inertia.php|resources/js/app.ts|resources/js/types/*|.editorconfig)
            echo misc-config ;;
        .gitignore|.env.example|CLAUDE.md)
            echo drift-only ;;
        artisan|public/*|storage/*|bootstrap/cache/.gitignore|database/.gitignore|LICENSE|README.md)
            echo not-in-scope ;;
        app/*|database/*|routes/*|bootstrap/*|config/*|tests/Pest.php|tests/Browser/*|tests/TestCase.php|tests/Unit/Models/*)
            echo never-touch ;;
        *)
            echo not-in-scope ;;
    esac
}

is_binary() {
    [ -s "$1" ] || return 1
    [ "$(file --mime-encoding -b -- "$1")" = "binary" ]
}

classify_path() {
    local path="$1"
    local project_file="$target/$path"
    local bucket
    bucket="$(bucket_for "$path")"

    if is_manifest "$path"; then
        printf 'manifest\t%s\t%s\n' "$bucket" "$path"
        return
    fi

    local upstream
    upstream="$(mktemp "${TMPDIR:-/tmp}/sync-skeleton-blob.XXXXXX")"
    if ! git -C "$kit_dir" show "origin/$branch:$path" >"$upstream" 2>/dev/null; then
        rm -f "$upstream"
        return
    fi

    if [[ ! -e "$project_file" ]]; then
        printf 'new\t%s\t%s\n' "$bucket" "$path"
    elif cmp -s "$upstream" "$project_file"; then
        printf 'identical\t%s\t%s\n' "$bucket" "$path"
    elif is_binary "$upstream" || is_binary "$project_file"; then
        printf 'differs-binary\t%s\t%s\n' "$bucket" "$path"
    else
        printf 'differs\t%s\t%s\n' "$bucket" "$path"
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
    printf 'deleted-upstream\t%s\t%s\n' "$(bucket_for "$path")" "$path"
done
