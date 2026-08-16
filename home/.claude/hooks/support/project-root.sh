#!/usr/bin/env bash
#
# Shared by quality-gate.sh and post-edit-gate.sh. A supported Composer project
# is the Git repository itself: composer.json must live at the Git toplevel.

# Sets $2 to the canonical Git toplevel for $1. Returns non-zero and leaves the
# output untouched when $1 is outside a Git repository or the repository root
# has no composer.json.
resolve_project_root() {
    local start_dir="$1" project_root_var="$2"
    local _rpr_root

    _rpr_root="$(git -C "$start_dir" rev-parse --show-toplevel 2>/dev/null)" || return 1
    _rpr_root="$(cd "$_rpr_root" && pwd -P)" || return 1
    [[ -f "$_rpr_root/composer.json" ]] || return 1

    printf -v "$project_root_var" '%s' "$_rpr_root"
}
