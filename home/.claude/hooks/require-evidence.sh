#!/usr/bin/env bash
#
# Stop hook. Runs `quality fast` for every project the edit hooks left dirty
# and blocks the turn while any gate still fails. Projects without a marker
# are ignored; see quality-gate.sh for the checks in fast mode.
#
# Markers are keyed by Composer project root. Scanning every marker below the
# session's Git toplevel also catches nested projects.
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

dirty_projects=()
while IFS= read -r marker; do
    project="${marker#"$config_home/runs"}"
    project="${project%.dirty}"
    case "$project" in
        "$git_root" | "$git_root"/*) dirty_projects+=("$project") ;;
    esac
done < <(find "$config_home/runs" -name '*.dirty' 2>/dev/null)

(( ${#dirty_projects[@]} == 0 )) && exit 0

still_dirty=()

for project in "${dirty_projects[@]}"; do
    # quality-gate.sh clears this project's own dirty marker on a clean run
    # and leaves it untouched on a failing one, so nothing here re-derives that.
    output="$(CLAUDE_PROJECT_DIR="$project" "$dispatcher" fast 2>&1)"
    status=$?

    # exit 3 (QUALITY_NO_PROJECT / QUALITY_NO_TOOLING) means there is nothing
    # left to prove clean for this marker, not that it failed.
    [[ "$status" == 0 || "$status" == 3 ]] && continue

    still_dirty+=("$project")
    printf '%s\n' "$output" >&2
    echo "'quality fast' just ran for $project and still failed, see output above. Fix it before treating this as done." >&2
done

(( ${#still_dirty[@]} == 0 )) && exit 0

exit 2
