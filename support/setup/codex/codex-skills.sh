#!/bin/bash

# Claude remains the only installer. Codex only receives symlinks to reviewed,
# harness-neutral skills from Claude's normal skill directory and plugin cache.
CODEX_COMPATIBLE_SKILLS=(
    bash-defensive-patterns
    code-review-dispatch
    codebase-design
    debug
    diagnosing-bugs
    frontend-design
    laravel-best-practices
    outcome-writing
    pr
    quality
    review
    spatie-javascript
    spatie-laravel-php
    spatie-security
    speeding-up-laravel-tests
    working-with-legacy-code
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

step "Linking Codex-compatible skills"
mkdir -p "$CODEX_SKILLS_TARGET"

plugin_skills_available=1
if ! command -v jq >/dev/null 2>&1; then
    warn "Skipping Claude plugin skills, jq is not installed"
    plugin_skills_available=0
elif ! jq -e '.plugins | type == "object"' "$CLAUDE_INSTALLED_PLUGINS" >/dev/null 2>&1; then
    warn "Skipping Claude plugin skills, installed_plugins.json is unavailable"
    plugin_skills_available=0
fi

linked=0
link_codex_skill() {
    local source_path="$1"
    local skill
    local target_path

    skill="$(basename "$source_path")"
    target_path="$CODEX_SKILLS_TARGET/$skill"

    if [ ! -f "$source_path/SKILL.md" ]; then
        warn "Skipping $skill, no SKILL.md found"
        return 0
    fi

    if [ -e "$target_path" ] && [ ! -L "$target_path" ]; then
        warn "Skipping $skill, $target_path is not a symlink"
        return 0
    fi

    ln -sfn "$source_path" "$target_path"
    linked=$((linked + 1))
}

# Remove only links created from the two Claude-managed source roots. This
# clears renamed skills and old plugin-version links without touching anything
# Codex or the user installed independently.
for target_path in "$CODEX_SKILLS_TARGET"/*; do
    [ -L "$target_path" ] || continue
    linked_path="$(readlink "$target_path")"
    case "$linked_path" in
        "$CODEX_SKILLS_SOURCE"/*) rm "$target_path" ;;
        "$CLAUDE_PLUGIN_CACHE"/*)
            if [ "$plugin_skills_available" -eq 1 ]; then
                rm "$target_path"
            fi
            ;;
    esac
done

for skill in "${CODEX_COMPATIBLE_SKILLS[@]}"; do
    link_codex_skill "$CODEX_SKILLS_SOURCE/$skill"
done

if [ "$plugin_skills_available" -eq 1 ]; then
    for plugin_skill in "${CODEX_COMPATIBLE_CLAUDE_PLUGIN_SKILLS[@]}"; do
        plugin_id="${plugin_skill%%:*}"
        relative_path="${plugin_skill#*:}"
        install_path="$(jq -r --arg plugin_id "$plugin_id" '
            .plugins[$plugin_id] // []
            | map(select(.scope == "user"))
            | sort_by(.lastUpdated)
            | last.installPath // empty
        ' "$CLAUDE_INSTALLED_PLUGINS")"

        if [ -z "$install_path" ] || [ ! -d "$install_path" ]; then
            warn "Skipping $plugin_id, no active Claude plugin installation found"
            continue
        fi

        plugin_source="$install_path/$relative_path"
        if [ -f "$plugin_source/SKILL.md" ]; then
            link_codex_skill "$plugin_source"
            continue
        fi

        if [ ! -d "$plugin_source" ]; then
            warn "Skipping $plugin_id, no compatible skill path found"
            continue
        fi

        for source_path in "$plugin_source"/*; do
            [ -f "$source_path/SKILL.md" ] || continue
            link_codex_skill "$source_path"
        done
    done
fi

success "$linked Codex-compatible skills linked"
