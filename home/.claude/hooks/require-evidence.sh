#!/usr/bin/env bash
#
# Stop hook. Runs `quality fast` when the edit hooks left the current project
# dirty and blocks the turn while the gate still fails. Projects without a
# marker are ignored; see quality-gate.sh for the checks in fast mode.
#
# Markers are keyed by the Git repository root.
#
# CLAUDE_QUALITY_DISABLE=1 prevents the edit hooks from creating markers.
#
# A failed gate returns exit 2 and is rerun on every stop attempt, so fixes are
# verified. Claude Code prevents an infinite loop by overriding a Stop hook
# after eight blocks without progress; CLAUDE_CODE_STOP_HOOK_BLOCK_CAP raises
# that limit. Each attempt reruns `quality fast`, including PHPStan and, unless
# disabled, the test suite.

set -u

dispatcher="$HOME/.claude/hooks/quality-gate.sh"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}/claude-quality"

input="$(cat)"

cwd="$(jq -r '.cwd // empty' <<<"$input")"
[[ -n "$cwd" ]] || exit 0

git_root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)" || exit 0
git_root="$(cd "$git_root" && pwd -P)" || exit 0

marker="$config_home/runs$git_root.dirty"
[[ -f "$marker" ]] || exit 0

# quality-gate.sh clears the marker on a clean run and leaves it untouched on
# a failing one, so nothing here re-derives that state.
output="$(CLAUDE_PROJECT_DIR="$git_root" "$dispatcher" fast 2>&1)"
status=$?

# exit 3 (QUALITY_NO_PROJECT / QUALITY_NO_TOOLING) means there is nothing left
# to prove clean for this marker, not that it failed.
[[ "$status" == 0 || "$status" == 3 ]] && exit 0

printf '%s\n' "$output" >&2
echo "'quality fast' just ran for $git_root and still failed, see output above. Fix it before treating this as done." >&2
exit 2
