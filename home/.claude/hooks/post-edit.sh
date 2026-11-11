#!/usr/bin/env bash
#
# PostToolUse hook for existing PHP files and composer.json files changed by Write or Edit.
#
# The edit has already happened, so the hook reports failures rather than
# blocking it: it runs the file gate, marks a project with detected tooling as
# dirty for the final check in require-evidence.sh, and exits 2 with the gate's
# output when the check fails, which is how Claude Code shows it to Claude.
#
# CLAUDE_QUALITY_DISABLE=1 skips this hook. A project with an equivalent local
# hook needs the flag because Claude Code combines rather than overrides hooks
# from different settings files; see README.md.

set -u

[[ -n "${CLAUDE_QUALITY_DISABLE:-}" ]] && exit 0

source "$(dirname -- "${BASH_SOURCE[0]}")/support/project-root.sh"
source "$(dirname -- "${BASH_SOURCE[0]}")/support/exit-codes.sh"

input="$(cat)"
file="$(jq -r '.tool_input.file_path // empty' <<<"$input")"

[[ -n "$file" && -f "$file" ]] || exit 0
[[ "$file" == *.php || "$(basename -- "$file")" == "composer.json" ]] || exit 0

canonical="$(
    cd "$(dirname -- "$file")" >/dev/null 2>&1 &&
    printf '%s/%s' "$(pwd -P)" "$(basename -- "$file")"
)" || exit 0

# quality-gate.sh independently resolves the project from $file. This lookup is
# only for the marker path and still handles Composer projects nested below the
# session's starting directory.
resolve_project_root "$(dirname -- "$canonical")" git_root root || exit 0

output="$("$HOME/.claude/hooks/quality-gate.sh" file "$file" 2>&1)"
status=$?

[[ "$status" == "$exit_nothing_to_check" ]] && exit 0

marker="${XDG_CONFIG_HOME:-$HOME/.config}/claude-quality/runs$root.dirty"
mkdir -p "$(dirname -- "$marker")" && : > "$marker"

if [[ "$status" != 0 ]]; then
    printf '%s\n' "$output" >&2
    echo "The file gate failed for $file. The edit is already applied; correct it in a follow-up edit." >&2
    exit 2
fi
