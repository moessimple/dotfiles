#!/usr/bin/env bash
#
# Shared by quality-gate.sh and post-edit-gate.sh. Resolves the nearest Composer
# project within a Git repository, including projects nested below a tool-less
# repository root, so every caller uses the same project boundary.

# Sets $2 to the Git toplevel and $3 to the nearest directory at or above $1
# containing composer.json, without searching above the Git root. Returns
# non-zero and leaves both outputs untouched when either root cannot be found;
# a bare vendor/bin directory is not treated as a Composer project.
resolve_project_root() {
    local start_dir="$1" git_root_var="$2" project_root_var="$3"
    # Prefixed so these never collide with the caller's own out-parameter
    # names (both direct callers name theirs "git_root"): a plain `local
    # git_root` here would shadow that name for the entire function body,
    # silently swallowing the printf -v write meant for the caller's variable.
    local _rpr_git_root _rpr_candidate

    _rpr_git_root="$(git -C "$start_dir" rev-parse --show-toplevel 2>/dev/null)" || return 1
    _rpr_git_root="$(cd "$_rpr_git_root" && pwd -P)" || return 1

    _rpr_candidate="$(cd "$start_dir" && pwd -P)" || return 1

    while :; do
        if [[ -f "$_rpr_candidate/composer.json" ]]; then
            printf -v "$git_root_var" '%s' "$_rpr_git_root"
            printf -v "$project_root_var" '%s' "$_rpr_candidate"
            return 0
        fi
        [[ "$_rpr_candidate" == "$_rpr_git_root" ]] && break
        _rpr_candidate="$(dirname -- "$_rpr_candidate")"
    done

    return 1
}
