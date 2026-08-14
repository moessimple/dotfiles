#!/usr/bin/env bats

load ../../support/quality_gate

setup() {
    new_quality_fixture
    new_project
    for tool in composer pint phpstan rector pest phpunit; do
        install_tool "$project" "$tool"
    done
    marker="$config_home/claude-quality/runs$project.dirty"
}

teardown() {
    teardown_quality_fixture
}

@test "a PHP edit is checked again before the response can finish" {
    [ ! -e "$marker" ]

    post_event post-php-edit.sh "$project/src/Example.php"
    [ -e "$marker" ]

    : > "$log"
    run stop_event false

    [ "$status" -eq 0 ]
    ran phpstan
    ran composer
    ran pest
    [ ! -e "$marker" ]
}
