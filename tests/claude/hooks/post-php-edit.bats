#!/usr/bin/env bats

load ../../support/quality_gate

setup() {
    new_quality_fixture
    new_project
    install_tool "$project" pint
    install_tool "$project" rector
    marker="$config_home/claude-quality/runs$project.dirty"
}

teardown() {
    teardown_quality_fixture
}

@test "the PHP edit hook is connected to Write and Edit events" {
    jq -e 'any(.hooks.PostToolUse[]; .matcher == "Write|Edit"
        and any(.hooks[]; .command == "\"$HOME/.claude/hooks/post-php-edit.sh\""))' \
        "$settings"
}

@test "editing a non-PHP file does not check or mark the project" {
    run post_event post-php-edit.sh "$project/README.md"

    [ "$status" -eq 0 ]
    [ ! -s "$log" ]
    [ ! -e "$marker" ]
}

@test "editing a PHP file runs its immediate code checks" {
    run post_event post-php-edit.sh "$project/src/Example.php"

    [ "$status" -eq 0 ]
    ran pint
    ran rector
}

@test "editing a PHP file marks the project for a final check" {
    run post_event post-php-edit.sh "$project/src/Example.php"

    [ "$status" -eq 0 ]
    [ -e "$marker" ]
}

@test "disabling automatic checks leaves an edited PHP file alone" {
    CLAUDE_QUALITY_DISABLE=1 run post_event post-php-edit.sh "$project/src/Example.php"

    [ "$status" -eq 0 ]
    [ ! -s "$log" ]
    [ ! -e "$marker" ]
}
