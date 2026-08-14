#!/usr/bin/env bash
#
# PostToolUse hook for composer.json files changed by Write or Edit. It stays
# separate from the PHP-only hook because manifest validation is project-wide.
#
# The edit has already happened, so the hook reports failures rather than
# blocking it. support/post-edit-gate.sh runs the gate, marks projects with
# detected tooling as dirty and shares reporting with post-php-edit.sh.
#
# CLAUDE_QUALITY_DISABLE=1 skips this hook entirely, same flag and same
# reasoning as post-php-edit.sh.

set -u

[[ -n "${CLAUDE_QUALITY_DISABLE:-}" ]] && exit 0

source "$(dirname -- "${BASH_SOURCE[0]}")/support/post-edit-gate.sh"

input="$(cat)"
file="$(jq -r '.tool_input.file_path // empty' <<<"$input")"

[[ -n "$file" && "$(basename -- "$file")" == "composer.json" && -f "$file" ]] || exit 0

run_post_edit_gate "$file"
