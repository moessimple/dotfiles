#!/usr/bin/env bash
# fetch-kit.sh - make the starter-kit tree available for comparison, preferring a
# local ~/Code clone and never modifying its working tree.
#
# Usage: fetch-kit.sh [profile]
#   profile   skeleton profile (default: laravel-starter-kit; only one exists)
#
# Prints one tab-separated line on stdout:
#   <kit_dir>\t<default-branch>\t<sha>
# where <sha> is the resolved tip of origin/<default-branch>.
#
# Exit codes:
#   1   clone or fetch failed, or the default branch could not be resolved
#  64   unknown profile
#  69   git is not installed
#
# A reused local clone is only `git fetch`ed, never checked out or reset. Every
# later comparison must read `git show origin/<branch>:<path>`, not the worktree.

set -euo pipefail

profile="${1:-laravel-starter-kit}"

if [[ "$profile" != "laravel-starter-kit" ]]; then
    echo "fetch-kit: unknown profile '$profile' (only 'laravel-starter-kit' is supported)" >&2
    exit 64
fi

if ! command -v git >/dev/null 2>&1; then
    echo "fetch-kit: git is not installed" >&2
    exit 69
fi

repo_url="https://github.com/moessimple/laravel-starter-kit.git"
origin_regex='github\.com[:/]moessimple/laravel-starter-kit(\.git)?$'
local_clone="$HOME/Code/laravel-starter-kit"

resolve_default_branch() {
    local kit_dir="$1" ref candidate
    if ref="$(git -C "$kit_dir" symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null)"; then
        echo "${ref#refs/remotes/origin/}"
        return
    fi
    for candidate in main master; do
        if git -C "$kit_dir" rev-parse --verify --quiet "origin/$candidate" >/dev/null; then
            echo "$candidate"
            return
        fi
    done
    echo "fetch-kit: cannot determine the kit default branch in '$kit_dir'" >&2
    exit 1
}

# Read the configured value, not `git remote get-url`, so an insteadOf rewrite
# cannot disguise a non-kit origin as the kit (or the reverse).
local_origin="$(git -C "$local_clone" config --get remote.origin.url 2>/dev/null || true)"

if [[ -d "$local_clone/.git" && "$local_origin" =~ $origin_regex ]]; then
    kit_dir="$local_clone"
    if ! git -C "$kit_dir" fetch --quiet origin; then
        echo "fetch-kit: 'git fetch' failed in '$kit_dir'" >&2
        exit 1
    fi
else
    kit_dir="$(mktemp -d "${TMPDIR:-/tmp}/sync-skeleton-kit.XXXXXX")"
    if ! git clone --quiet --filter=blob:none "$repo_url" "$kit_dir"; then
        echo "fetch-kit: 'git clone' of $repo_url failed" >&2
        exit 1
    fi
fi

branch="$(resolve_default_branch "$kit_dir")"
sha="$(git -C "$kit_dir" rev-parse "origin/$branch")"

printf '%s\t%s\t%s\n' "$kit_dir" "$branch" "$sha"
