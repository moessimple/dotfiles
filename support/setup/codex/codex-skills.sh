#!/bin/bash

# Claude remains the only installer. Codex only receives symlinks to reviewed,
# harness-neutral skills from Claude's normal skill directory and plugin cache.
CODEX_COMPATIBLE_SKILLS=(
    characterize-behavior
    clarity
    diagnosing-bugs
    document-product
    explain-changes
    pr
    raise-quality-gate
    speeding-up-laravel-tests
)

# Each entry is "<plugin>@<marketplace>:<path inside the installed version>".
# A path may point to one skill or a directory containing multiple skills.
CODEX_COMPATIBLE_CLAUDE_PLUGIN_SKILLS=(
    "agent-skills@addy-agent-skills:skills"
    "agent-browser@agent-browser:skills/agent-browser"
    "laravel@laravel:skills/starter-kit-upgrade"
)

CODEX_SKILLS_SOURCE="${CODEX_SKILLS_SOURCE:-$HOME/.dotfiles/home/.claude/skills}"
CODEX_SKILLS_TARGET="${CODEX_SKILLS_TARGET:-$HOME/.agents/skills}"
CLAUDE_PLUGIN_CACHE="${CLAUDE_PLUGIN_CACHE:-$HOME/.claude/plugins/cache}"
CLAUDE_INSTALLED_PLUGINS="${CLAUDE_INSTALLED_PLUGINS:-$HOME/.claude/plugins/installed_plugins.json}"

# Links <source path> into CODEX_SKILLS_TARGET. Returns 1 when it skips the skill, which it
# reports itself.
link_codex_skill() {
    local source_path="$1" skill target_path
    skill=$(basename "$source_path")
    target_path="$CODEX_SKILLS_TARGET/$skill"

    if [[ ! -f "$source_path/SKILL.md" ]]; then
        warn "Skipping $skill, no SKILL.md found"
        return 1
    fi

    if [[ -e "$target_path" ]] && [[ ! -L "$target_path" ]]; then
        warn "Skipping $skill, $target_path is not a symlink"
        return 1
    fi

    if ! ln -sfn "$source_path" "$target_path"; then
        warn "Could not link $skill to $target_path"
        return 1
    fi
}

link_codex_skills() {
    local plugin_skills_available=1 linked=0
    local target_path linked_path skill plugin_skill plugin_id relative_path install_path plugin_source source_path

    step "Linking Codex-compatible skills"
    mkdir -p "$CODEX_SKILLS_TARGET"

    if ! command -v jq &>/dev/null; then
        warn "Skipping Claude plugin skills, jq is not installed"
        plugin_skills_available=0
    elif ! jq -e '.plugins | type == "object"' "$CLAUDE_INSTALLED_PLUGINS" &>/dev/null; then
        warn "Skipping Claude plugin skills, installed_plugins.json is unavailable"
        plugin_skills_available=0
    fi

    # Remove only links created from the two Claude-managed source roots. This
    # clears renamed skills and old plugin-version links without touching anything
    # Codex or the user installed independently.
    for target_path in "$CODEX_SKILLS_TARGET"/*; do
        [[ -L "$target_path" ]] || continue
        linked_path=$(readlink "$target_path")
        case "$linked_path" in
            "$CODEX_SKILLS_SOURCE"/*) rm "$target_path" ;;
            "$CLAUDE_PLUGIN_CACHE"/*)
                if ((plugin_skills_available == 1)); then
                    rm "$target_path"
                fi
                ;;
        esac
    done

    for skill in "${CODEX_COMPATIBLE_SKILLS[@]}"; do
        if link_codex_skill "$CODEX_SKILLS_SOURCE/$skill"; then
            linked=$((linked + 1))
        fi
    done

    if ((plugin_skills_available == 1)); then
        for plugin_skill in "${CODEX_COMPATIBLE_CLAUDE_PLUGIN_SKILLS[@]}"; do
            plugin_id="${plugin_skill%%:*}"
            relative_path="${plugin_skill#*:}"
            install_path=$(jq -r --arg plugin_id "$plugin_id" '
                .plugins[$plugin_id] // []
                | map(select(.scope == "user"))
                | sort_by(.lastUpdated)
                | last.installPath // empty
            ' "$CLAUDE_INSTALLED_PLUGINS")

            if [[ -z "$install_path" ]] || [[ ! -d "$install_path" ]]; then
                warn "Skipping $plugin_id, no active Claude plugin installation found"
                continue
            fi

            plugin_source="$install_path/$relative_path"
            if [[ -f "$plugin_source/SKILL.md" ]]; then
                if link_codex_skill "$plugin_source"; then
                    linked=$((linked + 1))
                fi
                continue
            fi

            if [[ ! -d "$plugin_source" ]]; then
                warn "Skipping $plugin_id, no compatible skill path found"
                continue
            fi

            for source_path in "$plugin_source"/*; do
                [[ -f "$source_path/SKILL.md" ]] || continue
                if link_codex_skill "$source_path"; then
                    linked=$((linked + 1))
                fi
            done
        done
    fi

    success "$linked Codex-compatible skills linked"
}
