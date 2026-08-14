#!/usr/bin/env bash
#
# PostToolUse hook for existing PHP files changed by Write or Edit.
#
# The edit has already happened, so the hook reports failures rather than
# blocking it. support/post-edit-gate.sh runs the gate, marks projects with
# detected tooling as dirty and shares reporting with post-composer-edit.sh.
#
# CLAUDE_QUALITY_DISABLE=1 skips this hook. A project with an equivalent local
# hook needs the flag because Claude Code combines rather than overrides hooks
# from different settings files; see README.md.

set -u

[[ -n "${CLAUDE_QUALITY_DISABLE:-}" ]] && exit 0

source "$(dirname -- "${BASH_SOURCE[0]}")/support/post-edit-gate.sh"

input="$(cat)"
file="$(jq -r '.tool_input.file_path // empty' <<<"$input")"

[[ -n "$file" && "$file" == *.php && -f "$file" ]] || exit 0

run_post_edit_gate "$file"
