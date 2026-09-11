#!/usr/bin/env bats

load ../../support/test_helper

setup() {
    new_dotfiles_fixture
    source_dir="$dotfiles_dir/home/.claude/skills"
    skills_dir="$fixture/skills"
    plugin_cache="$fixture/plugin-cache"
    installed_plugins="$fixture/installed_plugins.json"
    target="$dotfiles_dir/support/setup/codex/codex-skills.sh"

    mkdir -p "$skills_dir"
    mkdir -p "$plugin_cache/addy-agent-skills/agent-skills/1.0.0/skills/plugin-workflow"
    mkdir -p "$plugin_cache/agent-browser/agent-browser/1.0.0/skills/agent-browser"
    mkdir -p "$plugin_cache/laravel/laravel/1.0.0/skills/starter-kit-upgrade"
    touch "$plugin_cache/addy-agent-skills/agent-skills/1.0.0/skills/plugin-workflow/SKILL.md"
    touch "$plugin_cache/agent-browser/agent-browser/1.0.0/skills/agent-browser/SKILL.md"
    touch "$plugin_cache/laravel/laravel/1.0.0/skills/starter-kit-upgrade/SKILL.md"
    jq -n --arg cache "$plugin_cache" '{
        plugins: {
            "agent-skills@addy-agent-skills": [{scope: "user", installPath: ($cache + "/addy-agent-skills/agent-skills/1.0.0"), lastUpdated: "2026-01-01"}],
            "agent-browser@agent-browser": [{scope: "user", installPath: ($cache + "/agent-browser/agent-browser/1.0.0"), lastUpdated: "2026-01-01"}],
            "laravel@laravel": [{scope: "user", installPath: ($cache + "/laravel/laravel/1.0.0"), lastUpdated: "2026-01-01"}]
        }
    }' > "$installed_plugins"
}

teardown() {
    teardown_dotfiles_fixture
}

run_codex_skills_setup() {
    CODEX_SKILLS_SOURCE="$source_dir" CODEX_SKILLS_TARGET="$skills_dir" \
        CLAUDE_PLUGIN_CACHE="$plugin_cache" CLAUDE_INSTALLED_PLUGINS="$installed_plugins" bash -c '
        step() { :; }
        success() { echo "$1"; }
        warn() { echo "$1"; }
        source "$1"
    ' bash "$target"
}

@test "reviewed harness-neutral skills are linked for Codex" {
    run run_codex_skills_setup

    assert_success
    [ -L "$skills_dir/debug" ]
    [ "$(readlink "$skills_dir/debug")" = "$source_dir/debug" ]
    [ -L "$skills_dir/pr" ]
    [ "$(readlink "$skills_dir/pr")" = "$source_dir/pr" ]
    [ -L "$skills_dir/review" ]
    [ "$(readlink "$skills_dir/review")" = "$source_dir/review" ]
    [ -L "$skills_dir/quality" ]
    [ "$(readlink "$skills_dir/quality")" = "$source_dir/quality" ]
    [ -L "$skills_dir/code-review-dispatch" ]
    [ "$(readlink "$skills_dir/code-review-dispatch")" = "$source_dir/code-review-dispatch" ]
    [ -L "$skills_dir/outcome-writing" ]
    [ "$(readlink "$skills_dir/outcome-writing")" = "$source_dir/outcome-writing" ]
    [ -L "$skills_dir/spatie-laravel-php" ]
    [ "$(readlink "$skills_dir/spatie-laravel-php")" = "$source_dir/spatie-laravel-php" ]
    [ -L "$skills_dir/plugin-workflow" ]
    [ -L "$skills_dir/agent-browser" ]
    [ -L "$skills_dir/starter-kit-upgrade" ]
}

@test "the Claude-activated plugin version is used" {
    inactive_skill="$plugin_cache/agent-browser/agent-browser/2.0.0/skills/agent-browser"
    mkdir -p "$inactive_skill"
    touch "$inactive_skill/SKILL.md"

    run run_codex_skills_setup

    assert_success
    [ "$(readlink "$skills_dir/agent-browser")" = "$plugin_cache/agent-browser/agent-browser/1.0.0/skills/agent-browser" ]
}

@test "stale managed links are removed without touching unrelated links" {
    mkdir -p "$plugin_cache/removed-plugin/1.0.0/skills/removed-skill" "$fixture/external-skill"
    ln -s "$plugin_cache/removed-plugin/1.0.0/skills/removed-skill" "$skills_dir/stale"
    ln -s "$fixture/external-skill" "$skills_dir/external"

    run run_codex_skills_setup

    assert_success
    [ ! -L "$skills_dir/stale" ]
    [ -L "$skills_dir/external" ]
}

@test "plugin links are preserved when installed plugin metadata is unavailable" {
    ln -s "$plugin_cache/addy-agent-skills/agent-skills/1.0.0/skills/plugin-workflow" "$skills_dir/plugin-workflow"
    installed_plugins="$fixture/missing-installed-plugins.json"

    run run_codex_skills_setup

    assert_success
    [ -L "$skills_dir/plugin-workflow" ]
    [ "$(readlink "$skills_dir/plugin-workflow")" = "$plugin_cache/addy-agent-skills/agent-skills/1.0.0/skills/plugin-workflow" ]
    assert_output_contains "Skipping Claude plugin skills, installed_plugins.json is unavailable"
}

@test "Claude-specific and duplicate skills are not linked for Codex" {
    run run_codex_skills_setup

    assert_success
    [ ! -e "$skills_dir/context7-auto-research" ]
    [ ! -e "$skills_dir/pdf" ]
    [ ! -e "$skills_dir/skill-creator" ]
}

@test "an existing skill directory is preserved" {
    mkdir -p "$skills_dir/outcome-writing"
    touch "$skills_dir/outcome-writing/keep"

    run run_codex_skills_setup

    assert_success
    [ ! -L "$skills_dir/outcome-writing" ]
    [ -f "$skills_dir/outcome-writing/keep" ]
    [ ! -e "$skills_dir/outcome-writing/outcome-writing" ]
    assert_output_contains "Skipping outcome-writing"
}

@test "a missing reviewed skill source does not create a dangling link" {
    source_dir="$fixture/missing-local-skills"
    mkdir -p "$source_dir"

    run run_codex_skills_setup

    assert_success
    [ ! -L "$skills_dir/debug" ]
    assert_output_contains "Skipping debug, no SKILL.md found"
    assert_output_does_not_contain "continue: only meaningful"
}
