#!/usr/bin/env bash
# apply-new-files.sh - write origin/<branch>'s content for every gate path the
# classifier reports as `new`, and stage each.
#
# Usage: apply-new-files.sh <profile> <kit_dir> <default-branch> <target>
#
# `differs`, `deleted-upstream`, and `ungrouped` are left for the agent to walk
# per SKILL.md Phase 5. Prints "applied <path>" per file written so the caller
# can list them in the commit message and the report.

set -euo pipefail

profile="${1:-}"
kit_dir="${2:-}"
branch="${3:-}"
target="${4:-}"
here="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

if [[ "$profile" != "laravel-starter-kit" || -z "$kit_dir" || -z "$branch" || -z "$target" ]]; then
    echo "Usage: apply-new-files.sh laravel-starter-kit <kit_dir> <default-branch> <target>" >&2
    exit 64
fi

"$here/classify.sh" "$profile" "$kit_dir" "$branch" "$target" \
    | awk -F'\t' '$1 == "new" { print $2 }' \
    | while IFS= read -r path; do
        [ -n "$path" ] || continue
        mkdir -p "$target/$(dirname "$path")"
        git -C "$kit_dir" show "origin/$branch:$path" > "$target/$path"
        git -C "$target" add -- "$path"
        echo "applied $path"
      done
