#!/usr/bin/env bash
# preflight.sh - verify the target project is in a state where sync-skeleton can
# safely operate. Run before any side effects.
#
# Usage: preflight.sh [profile] [target]
#   profile   skeleton profile (default: laravel-starter-kit; only one exists)
#   target    project directory  (default: git toplevel of the current directory)
#
# Checks, in order, each with a stable exit code the caller can branch on:
#   1  target is not inside a git repository
#   2  target has uncommitted changes (git status --short is written to stderr)
#   3  target does not look like a descendant of this skeleton
#  64  bad arguments / unknown profile
#
# On success prints "preflight: OK" and exits 0.

set -euo pipefail

profile="${1:-laravel-starter-kit}"
target="${2:-}"

if [[ "$profile" != "laravel-starter-kit" ]]; then
    echo "preflight: unknown profile '$profile' (only 'laravel-starter-kit' is supported)" >&2
    exit 64
fi

if [[ -z "$target" ]]; then
    target="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi

if [[ -z "$target" || ! -d "$target" ]] \
    || ! git -C "$target" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "preflight: '${target:-$PWD}' is not a git repository." >&2
    echo "Run this from inside the project, or pass its path as the second argument." >&2
    exit 1
fi

target="$(cd "$target" && git rev-parse --show-toplevel)"

if [[ -n "$(git -C "$target" status --porcelain)" ]]; then
    echo "preflight: '$target' has uncommitted changes." >&2
    echo "Commit or stash them first; sync-skeleton never stashes for you." >&2
    git -C "$target" status --short >&2
    exit 2
fi

# Descendant markers for the laravel-starter-kit profile: Boost config, agent
# rules, and an Inertia + Vue signature must all be present.
if [[ ! -f "$target/boost.json" ]] \
    || [[ ! -d "$target/.ai/rules" ]] \
    || { [[ ! -f "$target/resources/js/app.ts" ]] \
        && ! grep -q '@inertiajs/vue3' "$target/package.json" 2>/dev/null; }; then
    echo "preflight: '$target' does not look like a descendant of moessimple/laravel-starter-kit." >&2
    echo "Expected boost.json, .ai/rules/, and an Inertia + Vue signature." >&2
    exit 3
fi

echo "preflight: OK"
