#!/usr/bin/env bash
# plan-manifest.sh - diff a descendant's dev-dependency sets against the kit's
# and print the changes that make them match. This is the authoritative-mode
# input for the sync-skeleton quality-gate and frontend-tooling buckets: the
# starter kit's value is its dependency set, so the target's set is expected to
# converge on it rather than the reverse.
#
# Usage: plan-manifest.sh <profile> <kit_dir> <default-branch> <target>
#   profile          skeleton profile (only laravel-starter-kit is supported)
#   kit_dir          local kit clone from fetch-kit.sh
#   default-branch   kit default branch; the kit side is read at origin/<it>
#   target           the project directory (clean tree, from preflight.sh)
#
# Output, tab-separated, one directive per line, `add` then `align` then
# `remove`, each group sorted by name:
#   <action>\t<ecosystem>\t<name>\t<constraint>
#   action     add | align | remove
#   ecosystem  php  (composer.json require-dev) | npm (package.json devDependencies)
#   constraint the kit's constraint for add / align; the project's for remove
#
#   add     the kit requires <name>, the project does not
#   align   both require <name> at different constraints; adopt the kit's
#   remove  the project requires <name> from a family the kit deliberately
#           dropped and no longer carries any member of. For laravel-starter-kit
#           that is the eslint / prettier stack, replaced by vite-plus.
#
# Runtime `require` / `dependencies` are never inspected. No jq: `require-dev`
# and `devDependencies` are flat "name": "constraint" string maps. A manifest
# that is absent on either side contributes no directives for its ecosystem.
#
# Exit codes:
#  64   bad arguments / unknown profile

set -euo pipefail

profile="${1:-}"
kit_dir="${2:-}"
branch="${3:-}"
target="${4:-}"

if [[ "$profile" != "laravel-starter-kit" || -z "$kit_dir" || -z "$branch" || -z "$target" ]]; then
    echo "Usage: plan-manifest.sh laravel-starter-kit <kit_dir> <default-branch> <target>" >&2
    exit 64
fi

# npm dependency families the kit dropped in the vite-plus move. A project entry
# whose name matches this is a `remove` candidate, but only when the kit's
# devDependencies carry no member of the family (so a future kit that keeps one
# eslint plugin on purpose is respected).
npm_dropped_regex='^eslint$|^prettier$|^@eslint/|^eslint-plugin-|^eslint-config-|^eslint-import-resolver-|^@vue/eslint-config|^typescript-eslint$|^@stylistic/|^prettier-plugin-'

# Read a flat JSON object block ("<key>": { "name": "constraint", ... }) from
# stdin and print one "name<TAB>constraint" line per entry. Flat maps only: the
# block ends at the first line whose first non-space character is "}".
extract_block() {
    awk -v key="\"$1\"" '
        !inb && index($0, key) && index($0, "{") { inb = 1; next }
        inb && $0 ~ /^[[:space:]]*}/ { exit }
        inb && match($0, /"[^"]+"[[:space:]]*:[[:space:]]*"[^"]+"/) {
            pair = substr($0, RSTART, RLENGTH)
            split(pair, part, "\"")
            print part[2] "\t" part[4]
        }
    '
}

emit_ecosystem() {
    local eco="$1" key="$2" kit_json="$3" proj_json="$4" dropped="${5:-}"
    local kit_set proj_set
    kit_set="$(mktemp "${TMPDIR:-/tmp}/sync-skeleton-plan.XXXXXX")"
    proj_set="$(mktemp "${TMPDIR:-/tmp}/sync-skeleton-plan.XXXXXX")"
    printf '%s\n' "$kit_json" | extract_block "$key" | sort > "$kit_set"
    printf '%s\n' "$proj_json" | extract_block "$key" | sort > "$proj_set"

    local name kit_ver proj_ver
    while IFS=$'\t' read -r name kit_ver; do
        [ -n "$name" ] || continue
        proj_ver="$(awk -F'\t' -v n="$name" '$1 == n { print $2; exit }' "$proj_set")"
        if [ -z "$proj_ver" ]; then
            printf 'add\t%s\t%s\t%s\n' "$eco" "$name" "$kit_ver"
        fi
    done < "$kit_set"

    while IFS=$'\t' read -r name kit_ver; do
        [ -n "$name" ] || continue
        proj_ver="$(awk -F'\t' -v n="$name" '$1 == n { print $2; exit }' "$proj_set")"
        if [ -n "$proj_ver" ] && [ "$proj_ver" != "$kit_ver" ]; then
            printf 'align\t%s\t%s\t%s\n' "$eco" "$name" "$kit_ver"
        fi
    done < "$kit_set"

    if [ -n "$dropped" ] && ! cut -f1 "$kit_set" | grep -qE "$dropped"; then
        while IFS=$'\t' read -r name proj_ver; do
            [ -n "$name" ] || continue
            printf '%s\n' "$name" | grep -qE "$dropped" || continue
            printf 'remove\t%s\t%s\t%s\n' "$eco" "$name" "$proj_ver"
        done < "$proj_set"
    fi

    rm -f "$kit_set" "$proj_set"
}

# Empty string when the file is absent on that side; the ecosystem then yields
# no directives rather than failing the run.
kit_composer="$(git -C "$kit_dir" show "origin/$branch:composer.json" 2>/dev/null || true)"
kit_package="$(git -C "$kit_dir" show "origin/$branch:package.json" 2>/dev/null || true)"
proj_composer="$(cat "$target/composer.json" 2>/dev/null || true)"
proj_package="$(cat "$target/package.json" 2>/dev/null || true)"

emit_ecosystem php require-dev "$kit_composer" "$proj_composer"
emit_ecosystem npm devDependencies "$kit_package" "$proj_package" "$npm_dropped_regex"
