#!/usr/bin/env bats

load ../../support/test_helper
load ../../support/setup_cleanup_helper

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
    }' >"$installed_plugins"
}

teardown() {
    teardown_dotfiles_fixture
}

source_codex_skills_setup() {
    CODEX_SKILLS_SOURCE="$source_dir" CODEX_SKILLS_TARGET="$skills_dir" \
        CLAUDE_PLUGIN_CACHE="$plugin_cache" CLAUDE_INSTALLED_PLUGINS="$installed_plugins" run_setup_script "$target"
}

run_codex_skills_setup() {
    CODEX_SKILLS_SOURCE="$source_dir" CODEX_SKILLS_TARGET="$skills_dir" \
        CLAUDE_PLUGIN_CACHE="$plugin_cache" CLAUDE_INSTALLED_PLUGINS="$installed_plugins" call_setup_function "$target" codex_skills_link
}

@test "sourcing codex-skills.sh only defines its functions and links nothing" {
    # Act
    run source_codex_skills_setup

    # Assert
    assert_success
    [ -z "$output" ]
    [ -z "$(ls -A "$skills_dir")" ]
}

@test "reviewed harness-neutral skills are linked for Codex" {
    # Act
    run run_codex_skills_setup

    # Assert
    assert_success
    [ -L "$skills_dir/pr" ]
    [ "$(readlink "$skills_dir/pr")" = "$source_dir/pr" ]
    [ -L "$skills_dir/document-product" ]
    [ "$(readlink "$skills_dir/document-product")" = "$source_dir/document-product" ]
    [ -L "$skills_dir/characterize-behavior" ]
    [ "$(readlink "$skills_dir/characterize-behavior")" = "$source_dir/characterize-behavior" ]
    [ -L "$skills_dir/raise-quality-gate" ]
    [ "$(readlink "$skills_dir/raise-quality-gate")" = "$source_dir/raise-quality-gate" ]
    [ -L "$skills_dir/plugin-workflow" ]
    [ -L "$skills_dir/agent-browser" ]
    [ -L "$skills_dir/starter-kit-upgrade" ]
}

@test "a failed skill symlink is reported in the final summary while other skills are linked" {
    given_fake_bin_on_path
    write_fake_binary ln 'if [[ "$2" == */pr ]]; then
    exit 1
fi
exec /bin/ln "$@"'

    run env CODEX_SKILLS_SOURCE="$source_dir" CODEX_SKILLS_TARGET="$skills_dir" \
        CLAUDE_PLUGIN_CACHE="$plugin_cache" CLAUDE_INSTALLED_PLUGINS="$installed_plugins" \
        /bin/bash -ec '
            source "$1/support/setup/output.sh"
            source "$1/support/setup/codex/codex-skills.sh"
            codex_skills_link
            finish "Configuration applied"
        ' bash "$dotfiles_dir"

    [ "$status" -eq 1 ]
    assert_output_contains "Could not link pr"
    assert_output_contains "Finished with 1 problem(s):"
    assert_output_does_not_contain "Configuration applied"
    [ ! -L "$skills_dir/pr" ]
    [ -L "$skills_dir/document-product" ]
}

@test "the Claude-activated plugin version is used" {
    # Arrange
    inactive_skill="$plugin_cache/agent-browser/agent-browser/2.0.0/skills/agent-browser"
    mkdir -p "$inactive_skill"
    touch "$inactive_skill/SKILL.md"

    # Act
    run run_codex_skills_setup

    # Assert
    assert_success
    [ "$(readlink "$skills_dir/agent-browser")" = "$plugin_cache/agent-browser/agent-browser/1.0.0/skills/agent-browser" ]
}

@test "stale managed links are removed without touching unrelated links" {
    # Arrange
    mkdir -p "$plugin_cache/removed-plugin/1.0.0/skills/removed-skill" "$fixture/external-skill"
    ln -s "$plugin_cache/removed-plugin/1.0.0/skills/removed-skill" "$skills_dir/stale"
    ln -s "$fixture/external-skill" "$skills_dir/external"

    # Act
    run run_codex_skills_setup

    # Assert
    assert_success
    [ ! -L "$skills_dir/stale" ]
    [ -L "$skills_dir/external" ]
}

@test "plugin links are preserved when installed plugin metadata is unavailable" {
    # Arrange
    ln -s "$plugin_cache/addy-agent-skills/agent-skills/1.0.0/skills/plugin-workflow" "$skills_dir/plugin-workflow"
    installed_plugins="$fixture/missing-installed-plugins.json"

    # Act
    run run_codex_skills_setup

    # Assert
    assert_success
    [ -L "$skills_dir/plugin-workflow" ]
    [ "$(readlink "$skills_dir/plugin-workflow")" = "$plugin_cache/addy-agent-skills/agent-skills/1.0.0/skills/plugin-workflow" ]
    assert_output_contains "WARN: Skipping Claude plugin skills, installed_plugins.json is unavailable"
}

@test "Claude-specific and duplicate skills are not linked for Codex" {
    # Act
    run run_codex_skills_setup

    # Assert
    assert_success
    assert_path_does_not_exist "$skills_dir/pdf"
    assert_path_does_not_exist "$skills_dir/skill-creator"
}

@test "an existing skill directory is preserved" {
    # Arrange
    mkdir -p "$skills_dir/explain-changes"
    touch "$skills_dir/explain-changes/keep"

    # Act
    run run_codex_skills_setup

    # Assert
    assert_success
    [ ! -L "$skills_dir/explain-changes" ]
    assert_file_exists "$skills_dir/explain-changes/keep"
    assert_path_does_not_exist "$skills_dir/explain-changes/explain-changes"
    assert_output_contains "WARN: Skipping explain-changes"
}

@test "a missing reviewed skill source does not create a dangling link" {
    # Arrange
    source_dir="$fixture/missing-local-skills"
    mkdir -p "$source_dir"

    # Act
    run run_codex_skills_setup

    # Assert
    assert_success
    [ ! -L "$skills_dir/pr" ]
    assert_output_contains "WARN: Skipping pr, no SKILL.md found"
    assert_output_does_not_contain "continue: only meaningful"
}
