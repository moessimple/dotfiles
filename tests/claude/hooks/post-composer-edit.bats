#!/usr/bin/env bats

load ../../support/quality_gate

setup() {
    new_quality_fixture
    new_project
    install_tool "$project" composer
    marker="$config_home/claude-quality/runs$project.dirty"
}

teardown() {
    teardown_quality_fixture
}

@test "the Composer edit hook is connected to Write and Edit events" {
    jq -e 'any(.hooks.PostToolUse[]; .matcher == "Write|Edit"
        and any(.hooks[]; .command == "\"$HOME/.claude/hooks/post-composer-edit.sh\""))' \
        "$settings"
}

@test "editing composer.json validates it" {
    run post_event post-composer-edit.sh "$project/composer.json"

    [ "$status" -eq 0 ]
    ran composer
    ran_with_argument composer validate
}

@test "editing composer.json marks the project for a final check" {
    run post_event post-composer-edit.sh "$project/composer.json"

    [ "$status" -eq 0 ]
    [ -e "$marker" ]
}

@test "editing a composer.json outside the repository root does nothing" {
    other_manifest="$project/packages/example/composer.json"
    mkdir -p "$(dirname -- "$other_manifest")"
    printf '{}\n' > "$other_manifest"

    run post_event post-composer-edit.sh "$other_manifest"

    [ "$status" -eq 0 ]
    [ ! -s "$log" ]
    [ ! -e "$marker" ]
}
