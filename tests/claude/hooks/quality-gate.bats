#!/usr/bin/env bats

load ../../support/quality_gate

setup() {
    new_quality_fixture
}

teardown() {
    teardown_quality_fixture
}

@test "a full check covers formatting, analysis, dependencies, and tests" {
    # Arrange
    given_project_with_tools composer pint phpstan rector pest phpunit

    # Act
    run run_gate full

    # Assert
    assert_success
    assert_tool_ran pint
    assert_tool_ran phpstan
    assert_tool_ran rector
    assert_tool_ran composer
    assert_tool_ran pest
}

@test "a fast check covers changed code, analysis, the manifest, and tests" {
    # Arrange
    given_project_with_tools composer pint phpstan rector pest phpunit

    # Act
    run run_gate fast

    # Assert
    assert_success
    assert_tool_ran pint
    assert_tool_ran phpstan
    assert_tool_ran rector
    assert_tool_ran composer
    assert_tool_ran pest
}

@test "a fast check limits code checks to changed PHP files" {
    # Arrange
    given_project_with_tools composer pint phpstan rector pest phpunit
    printf '<?php\n' > "$project/src/Unchanged.php"
    commit_project
    printf '<?php\n// changed\n' > "$project/src/Example.php"
    printf '<?php\n' > "$project/src/Staged.php"
    printf '<?php\n' > "$project/src/Untracked.php"
    git -C "$git_root" add "$project/src/Staged.php"

    # Act
    run run_gate fast

    # Assert
    assert_success
    assert_tool_ran_with_argument pint --dirty
    assert_tool_ran_with_argument rector src/Example.php
    assert_tool_ran_with_argument rector src/Staged.php
    assert_tool_ran_with_argument rector src/Untracked.php
    assert_tool_did_not_run_with_argument rector src/Unchanged.php
}

@test "a fast check can skip tests without skipping code checks" {
    # Arrange
    given_project_with_tools composer pint phpstan rector pest phpunit

    # Act
    CLAUDE_QUALITY_SKIP_TESTS=1 run run_gate fast

    # Assert
    assert_success
    assert_tool_ran pint
    assert_tool_ran rector
    assert_tool_did_not_run pest
}

@test "a fast check can skip Rector without skipping the other checks" {
    # Arrange
    given_project_with_tools composer pint phpstan rector pest phpunit

    # Act
    CLAUDE_QUALITY_SKIP_RECTOR=1 run run_gate fast

    # Assert
    assert_success
    assert_tool_ran pint
    assert_tool_did_not_run rector
    assert_tool_ran pest
}

@test "a fast check on a nested project scopes changed files relative to that project, not the Git root" {
    # Arrange
    given_nested_project_with_tools composer pint rector
    commit_project
    printf '<?php\n// changed\n' > "$project/src/Example.php"

    # Act
    run run_gate_for_project "$project" fast

    # Assert
    assert_success
    assert_tool_ran_with_argument rector src/Example.php
    assert_tool_did_not_run_with_argument rector packages/example/src/Example.php
}

@test "checking one PHP file runs only the checks for that file" {
    # Arrange
    given_project_with_tools pint phpstan rector

    # Act
    run run_gate file "$project/src/Example.php"

    # Assert
    assert_success
    assert_tool_ran pint
    assert_tool_ran rector
    assert_tool_ran_with_argument pint "$project/src/Example.php"
    assert_tool_ran_with_argument rector "$project/src/Example.php"
    assert_tool_did_not_run phpstan
}

@test "checking one PHP file can skip Rector" {
    # Arrange
    given_project_with_tools pint rector

    # Act
    CLAUDE_QUALITY_SKIP_RECTOR=1 run run_gate file "$project/src/Example.php"

    # Assert
    assert_success
    assert_tool_ran pint
    assert_tool_did_not_run rector
}

@test "checking a PHP file under a hidden directory does nothing" {
    # Arrange
    given_project_with_tools pint rector
    mkdir -p "$project/.ai/guidelines"
    printf '<?php\n' > "$project/.ai/guidelines/example.blade.php"

    # Act
    run run_gate file "$project/.ai/guidelines/example.blade.php"

    # Assert
    assert_success
    assert_tool_did_not_run pint
    assert_tool_did_not_run rector
}

@test "checking a hidden PHP file does nothing" {
    # Arrange
    given_project_with_tools pint rector
    printf '<?php\n' > "$project/.php-cs-fixer.php"

    # Act
    run run_gate file "$project/.php-cs-fixer.php"

    # Assert
    assert_success
    assert_tool_did_not_run pint
    assert_tool_did_not_run rector
}

@test "quality uses the fast check by default" {
    # Arrange
    given_project_with_tools composer pint phpstan rector pest phpunit

    # Act
    run run_quality

    # Assert
    assert_success
    assert_tool_ran phpstan
    assert_tool_ran rector
    assert_tool_ran pest
}

@test "quality full includes the test suite" {
    # Arrange
    given_project_with_tools composer pint phpstan rector pest phpunit

    # Act
    run run_quality full

    # Assert
    assert_success
    assert_tool_ran pest
}

@test "quality help explains that fast is the default" {
    # Arrange
    help_option=--help

    # Act
    run run_quality "$help_option"

    # Assert
    assert_success
    assert_output_contains "default: fast"
}

@test "quality status shows the latest result for the repository project" {
    # Arrange
    given_composer_project_without_quality_tools
    record="$config_home/claude-quality/runs$project.json"
    write_quality_record "$record" "$project" fast 0

    # Act
    run run_quality_status

    # Assert
    assert_success
    assert_output_json_value root "$project"
    assert_output_json_value mode fast
}

@test "a fast check records what was checked and whether it passed" {
    # Arrange
    given_project_with_tools composer pint phpstan rector pest phpunit

    # Act
    run run_gate fast

    # Assert
    assert_success
    record="$config_home/claude-quality/runs$project.json"
    assert_file_exists "$record"
    assert_record_value "$record" root "$project"
    assert_record_value "$record" mode fast
    assert_record_value "$record" sha none
    assert_record_value "$record" tree dirty
    assert_record_exit_is_success "$record"
}

@test "a failed check records the failure" {
    # Arrange
    given_project_with_tools composer pint phpstan rector pest phpunit
    failing_tool=phpstan

    # Act
    QUALITY_FAIL_TOOL="$failing_tool" run run_gate fast

    # Assert
    assert_failure
    record="$config_home/claude-quality/runs$project.json"
    assert_record_exit_is_failure "$record"
}

@test "a project without quality tools reports nothing to check and clears its marker" {
    # Arrange
    empty_project="$fixture/empty-project"
    mkdir -p "$empty_project/vendor/bin"
    git init -q "$empty_project"
    printf '{}\n' > "$empty_project/composer.json"

    marker="$config_home/claude-quality/runs$empty_project.dirty"
    mkdir -p "$(dirname -- "$marker")"
    touch "$marker"

    # Act
    run run_gate_for_project_without_composer "$empty_project" fast

    # Assert
    assert_status 3
    assert_output_contains "QUALITY_NO_TOOLING"
    assert_path_does_not_exist "$marker"
}

@test "a fast check runs Laravel tests when only Artisan is available" {
    # Arrange
    given_project_with_artisan_test_runner

    # Act
    PATH="$(path_without_composer)" run run_gate fast

    # Assert
    assert_success
    assert_tool_ran artisan
}

@test "a directory without a Composer project reports nothing to check" {
    # Arrange
    empty_dir="$fixture/no-project"
    mkdir -p "$empty_dir"
    git init -q "$empty_dir"

    # Act
    run run_gate_for_project "$empty_dir" fast

    # Assert
    assert_status 3
    assert_output_contains "QUALITY_NO_PROJECT"
}

@test "a Composer project nested below a tool-less Git root is found" {
    # Arrange
    given_nested_project_with_tools composer pint

    # Act
    run run_gate_for_project "$project" fast

    # Assert
    assert_success
    assert_tool_ran pint
}

@test "file mode walks up from a file's own directory to find its nested project" {
    # Arrange
    given_nested_project_with_tools pint rector

    # Act
    run run_gate file "$project/src/Example.php"

    # Assert
    assert_success
    assert_tool_ran pint
    assert_tool_ran rector
}

@test "file mode validates a composer.json nested below the Git root" {
    # Arrange
    given_nested_project_with_tools composer

    # Act
    run run_gate file "$project/composer.json"

    # Assert
    assert_success
    assert_tool_ran composer
}

@test "running quality file from inside a sibling project still gates the file's own project" {
    # Arrange
    given_nested_project_with_tools pint
    other_project="$git_root/other"
    mkdir -p "$other_project"
    printf '{}\n' > "$other_project/composer.json"

    # Act
    run run_gate_for_project "$other_project" file "$project/src/Example.php"

    # Assert
    assert_success
    assert_tool_ran pint
}

@test "an unknown check mode shows usage" {
    # Arrange
    given_project_with_tools composer pint phpstan rector pest phpunit

    # Act
    run run_gate bogus

    # Assert
    assert_status 64
    assert_output_contains "Usage:"
}

@test "checking one file requires a path" {
    # Arrange
    given_project_with_tools pint rector

    # Act
    run run_gate file

    # Assert
    assert_status 64
}

@test "checking a missing file explains the problem" {
    # Arrange
    given_project_with_tools pint rector

    # Act
    run run_gate file "$project/src/DoesNotExist.php"

    # Assert
    assert_status 64
    assert_output_contains "Not a regular file"
}

@test "a path excluded from Pint can still be checked by Rector" {
    # Arrange
    given_project_with_tools pint rector
    configure_pint_to_exclude src/Legacy
    mkdir -p "$project/src/Legacy"
    printf '<?php\n' > "$project/src/Legacy/Old.php"

    # Act
    run run_gate file "$project/src/Legacy/Old.php"

    # Assert
    assert_success
    assert_tool_did_not_run pint
    assert_tool_ran rector
}

@test "Pint still checks files outside its excluded paths" {
    # Arrange
    given_project_with_tools pint
    configure_pint_to_exclude src/Legacy

    # Act
    run run_gate file "$project/src/Example.php"

    # Assert
    assert_success
    assert_tool_ran pint
}

@test "a path denied by Pint can still be checked by Rector" {
    # Arrange
    given_project_with_tools pint rector
    configure_pint_to_deny tmp
    mkdir -p "$project/tmp"
    printf '<?php\n' > "$project/tmp/Scratch.php"

    # Act
    run run_gate file "$project/tmp/Scratch.php"

    # Assert
    assert_success
    assert_tool_did_not_run pint
    assert_tool_ran rector
}

@test "a full check validates and audits dependencies" {
    # Arrange
    given_project_with_tools composer

    # Act
    run run_gate full

    # Assert
    assert_success
    assert_tool_ran_with_argument composer validate
    assert_tool_ran_with_argument composer audit
}

@test "a fast check validates dependencies without auditing them" {
    # Arrange
    given_project_with_tools composer

    # Act
    run run_gate fast

    # Assert
    assert_success
    assert_tool_ran_with_argument composer validate
    assert_tool_did_not_run_with_argument composer audit
}

@test "a project with Pest and PHPUnit uses Pest" {
    # Arrange
    given_project_with_tools composer pest phpunit

    # Act
    run run_gate fast

    # Assert
    assert_success
    assert_tool_ran pest
    assert_tool_did_not_run phpunit
}

@test "a Pest suite runs in parallel when ParaTest is available" {
    # Arrange
    given_project_with_tools composer pest phpunit paratest

    # Act
    run run_gate fast

    # Assert
    assert_success
    assert_tool_ran_with_argument pest --parallel
}

@test "a Pest suite runs normally without ParaTest" {
    # Arrange
    given_project_with_tools composer pest phpunit

    # Act
    run run_gate fast

    # Assert
    assert_success
    assert_tool_did_not_run_with_argument pest --parallel
}

@test "a PHPUnit project uses ParaTest when it is available" {
    # Arrange
    given_project_with_tools composer phpunit paratest

    # Act
    run run_gate fast

    # Assert
    assert_success
    assert_tool_ran paratest
    assert_tool_did_not_run phpunit
}

@test "an Artisan test suite runs in parallel when ParaTest is available" {
    # Arrange
    given_project_with_tools composer paratest
    install_artisan_test_runner

    # Act
    run run_gate fast

    # Assert
    assert_success
    assert_tool_ran artisan
    assert_tool_ran_with_argument artisan --parallel
}

@test "the Herd PHP shim directory is removed after the gate runs" {
    # Arrange
    given_project_with_tools composer pint
    given_herd_resolving_to_system_php
    given_mktemp_creating_directories_under_fixture

    # Act
    run run_gate fast

    # Assert
    assert_success
    [ -z "$(ls -A "$mktemp_tracking_dir")" ]
}
