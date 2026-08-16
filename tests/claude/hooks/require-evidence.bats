#!/usr/bin/env bats

load ../../support/quality_gate

setup() {
    new_quality_fixture
    new_project
    for tool in composer pint phpstan rector pest phpunit; do
        install_tool "$project" "$tool"
    done
    marker="$config_home/claude-quality/runs$project.dirty"
    post_event post-php-edit.sh "$project/src/Example.php"
    : > "$log"
}

teardown() {
    teardown_quality_fixture
}

@test "the final check is connected to Stop events with enough time to finish" {
    jq -e 'any(.hooks.Stop[]; any(.hooks[];
        .command == "\"$HOME/.claude/hooks/require-evidence.sh\"" and .timeout == 120))' \
        "$settings"
}

@test "a final check runs all available project checks" {
    run stop_event false

    [ "$status" -eq 0 ]
    ran pint
    ran phpstan
    ran rector
    ran composer
    ran pest
}

@test "a successful final check clears the dirty project" {
    run stop_event false

    [ "$status" -eq 0 ]
    [ ! -e "$marker" ]
}

@test "a final check can skip tests without skipping code checks" {
    CLAUDE_QUALITY_SKIP_TESTS=1 run stop_event false

    [ "$status" -eq 0 ]
    ran pint
    ran rector
    ! ran pest
}

@test "a final check can skip Rector without skipping the other checks" {
    CLAUDE_QUALITY_SKIP_RECTOR=1 run stop_event false

    [ "$status" -eq 0 ]
    ran pint
    ! ran rector
    ran pest
}

@test "a failed final check blocks the response" {
    QUALITY_FAIL_TOOL=phpstan run stop_event false

    [ "$status" -eq 2 ]
}

@test "a failed final check keeps the project dirty" {
    QUALITY_FAIL_TOOL=phpstan run stop_event false

    [ -e "$marker" ]
}

@test "one failed project check does not prevent the remaining checks" {
    QUALITY_FAIL_TOOL=phpstan run stop_event false

    ran pint
    ran rector
    ran composer
    ran pest
}

@test "a repeated final check still blocks while the project is broken" {
    QUALITY_FAIL_TOOL=phpstan run stop_event true

    [ "$status" -eq 2 ]
    ran phpstan
}

@test "a repeated final check succeeds after the project is fixed" {
    run stop_event true

    [ "$status" -eq 0 ]
    ran phpstan
    [ ! -e "$marker" ]
}

@test "a dirty project without tooling does not block the response" {
    rm -f "$project/composer.json"

    run stop_event false

    [ "$status" -eq 0 ]
}

@test "a final check without a working directory does nothing" {
    run stop_event_json '{}'

    [ "$status" -eq 0 ]
    [ ! -s "$log" ]
}

@test "a final check outside a Git repository does nothing" {
    non_git_dir="$fixture/not-a-repo"
    mkdir -p "$non_git_dir"

    run stop_event_json "$(jq -nc --arg cwd "$non_git_dir" '{cwd: $cwd}')"

    [ "$status" -eq 0 ]
    [ ! -s "$log" ]
}

@test "a final check with no dirty projects does nothing" {
    rm -f "$marker"

    run stop_event false

    [ "$status" -eq 0 ]
    [ ! -s "$log" ]
}

@test "a final check ignores dirty projects from another repository" {
    other_repo="$fixture/other-repo"
    other_project="$other_repo"
    mkdir -p "$other_project/src" "$other_project/vendor/bin"
    git init -q "$other_repo"
    printf '{}\n' > "$other_project/composer.json"
    printf '<?php\n' > "$other_project/src/Example.php"
    install_tool "$other_project" pint

    other_marker="$config_home/claude-quality/runs$other_project.dirty"
    post_event post-php-edit.sh "$other_project/src/Example.php"
    [ -e "$other_marker" ]

    : > "$log"
    run stop_event false

    [ "$status" -eq 0 ]
    [ ! -e "$marker" ]
    [ -e "$other_marker" ]
    [ "$(ran_count pint)" -eq 1 ]
}
