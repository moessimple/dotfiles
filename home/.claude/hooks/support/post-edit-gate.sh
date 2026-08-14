#!/usr/bin/env bash
#
# Shared by the PHP and composer.json PostToolUse hooks. After either hook
# matches its file type, this runs the file gate, marks the project dirty and
# reports failures consistently.

source "$(dirname -- "${BASH_SOURCE[0]}")/project-root.sh"

# Exits the calling hook script directly, the same way both hooks already
# did inline: 0 when there's no project to gate or the gate passed, 2 with
# the gate's own output on failure. Never returns.
run_post_edit_gate() {
    local file="$1"
    local dispatcher="$HOME/.claude/hooks/quality-gate.sh"
    local config_home="${XDG_CONFIG_HOME:-$HOME/.config}/claude-quality"

    # quality-gate.sh independently resolves the project from $file. This
    # lookup is only for the marker path and still handles Composer projects
    # nested below the session's starting directory.
    resolve_project_root "$(dirname -- "$file")" git_root root || exit 0

    local output status
    output="$("$dispatcher" file "$file" 2>&1)"
    status=$?

    [[ "$status" == 3 ]] && exit 0

    local marker="$config_home/runs$root.dirty"
    mkdir -p "$(dirname -- "$marker")" && : > "$marker"

    case "$status" in
        0)
            exit 0
            ;;
        *)
            printf '%s\n' "$output" >&2
            echo "The file gate failed for $file. The edit is already applied; correct it in a follow-up edit." >&2
            exit 2
            ;;
    esac
}
