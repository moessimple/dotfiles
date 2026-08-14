#!/usr/bin/env bats

load ../../support/quality_gate

setup() {
    new_quality_fixture
    new_project
    for tool in composer pint phpstan rector pest phpunit; do
        install_tool "$project" "$tool"
    done
}

teardown() {
    teardown_quality_fixture
}

@test "a full check covers formatting, analysis, dependencies, and tests" {
    run run_gate full

    [ "$status" -eq 0 ]
    ran pint
    ran phpstan
    ran rector
    ran composer
    ran pest
}

@test "a fast check covers changed code, analysis, the manifest, and tests" {
    run run_gate fast

    [ "$status" -eq 0 ]
    ran pint
    ran phpstan
    ran rector
    ran composer
    ran pest
}

@test "a fast check limits code checks to changed PHP files" {
    printf '<?php\n' > "$project/src/Unchanged.php"
    commit_project
    printf '<?php\n// changed\n' > "$project/src/Example.php"
    printf '<?php\n' > "$project/src/Staged.php"
    printf '<?php\n' > "$project/src/Untracked.php"
    git -C "$git_root" add "$project/src/Staged.php"

    run run_gate fast

    [ "$status" -eq 0 ]
    ran_with_argument pint --dirty
    ran_with_argument rector src/Example.php
    ran_with_argument rector src/Staged.php
    ran_with_argument rector src/Untracked.php
    ! ran_with_argument rector src/Unchanged.php
}

@test "a fast check can skip tests without skipping code checks" {
    CLAUDE_QUALITY_SKIP_TESTS=1 run run_gate fast

    [ "$status" -eq 0 ]
    ran pint
    ran rector
    ! ran pest
}

@test "a fast check can skip Rector without skipping the other checks" {
    CLAUDE_QUALITY_SKIP_RECTOR=1 run run_gate fast

    [ "$status" -eq 0 ]
    ran pint
    ! ran rector
    ran pest
}

@test "checking one PHP file runs only the checks for that file" {
    run run_gate file "$project/src/Example.php"

    [ "$status" -eq 0 ]
    ran pint
    ran rector
    ran_with_argument pint "$project/src/Example.php"
    ran_with_argument rector "$project/src/Example.php"
    ! ran phpstan
}

@test "checking one PHP file can skip Rector" {
    CLAUDE_QUALITY_SKIP_RECTOR=1 run run_gate file "$project/src/Example.php"

    [ "$status" -eq 0 ]
    ran pint
    ! ran rector
}

@test "checking a PHP file under a hidden directory does nothing" {
    mkdir -p "$project/.ai/guidelines"
    printf '<?php\n' > "$project/.ai/guidelines/example.blade.php"

    run run_gate file "$project/.ai/guidelines/example.blade.php"

    [ "$status" -eq 0 ]
    ! ran pint
    ! ran rector
}

@test "checking a hidden PHP file does nothing" {
    printf '<?php\n' > "$project/.php-cs-fixer.php"

    run run_gate file "$project/.php-cs-fixer.php"

    [ "$status" -eq 0 ]
    ! ran pint
    ! ran rector
}

@test "quality uses the fast check by default" {
    run run_quality

    [ "$status" -eq 0 ]
    ran phpstan
    ran rector
    ran pest
}

@test "quality full includes the test suite" {
    run run_quality full

    [ "$status" -eq 0 ]
    ran pest
}

@test "quality help explains that fast is the default" {
    run run_quality --help

    [[ "$output" == *'default: fast'* ]]
}

@test "quality status shows the latest result for a nested project" {
    record="$config_home/claude-quality/runs$project.json"
    mkdir -p "$(dirname -- "$record")"
    jq -n --arg root "$project" '{root: $root, mode: "fast", exit: 0}' > "$record"

    run run_quality_status

    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | jq -r .root)" = "$project" ]
    [ "$(printf '%s' "$output" | jq -r .mode)" = "fast" ]
}

@test "a fast check records what was checked and whether it passed" {
    run run_gate fast

    [ "$status" -eq 0 ]
    record="$config_home/claude-quality/runs$project.json"
    [ -f "$record" ]
    [ "$(jq -r .root "$record")" = "$project" ]
    [ "$(jq -r .mode "$record")" = "fast" ]
    [ "$(jq -r .sha "$record")" = "none" ]
    [ "$(jq -r .tree "$record")" = "dirty" ]
    [ "$(jq -r .exit "$record")" -eq 0 ]
}

@test "a failed check records the failure" {
    QUALITY_FAIL_TOOL=phpstan run run_gate fast

    record="$config_home/claude-quality/runs$project.json"
    [ "$(jq -r .exit "$record")" -ne 0 ]
}

@test "a project without quality tools reports nothing to check and clears its marker" {
    empty_project="$git_root/empty"
    mkdir -p "$empty_project/vendor/bin"
    printf '{}\n' > "$empty_project/composer.json"

    marker="$config_home/claude-quality/runs$empty_project.dirty"
    mkdir -p "$(dirname -- "$marker")"
    touch "$marker"

    run env PATH="$(path_without_composer)" XDG_CONFIG_HOME="$config_home" CLAUDE_PROJECT_DIR="$empty_project" "$gate" fast

    [ "$status" -eq 3 ]
    [[ "$output" == *'QUALITY_NO_TOOLING'* ]]
    [ ! -e "$marker" ]
}

@test "a fast check runs Laravel tests when only Artisan is available" {
    rm "$fake_bin/composer"
    rm "$project/vendor/bin/"*
    cat > "$project/artisan" <<'ARTISAN'
<?php
$tool = 'artisan';
file_put_contents(getenv('QUALITY_TEST_LOG'), "$tool\n", FILE_APPEND);
exit($tool === getenv('QUALITY_FAIL_TOOL') ? 1 : 0);
ARTISAN

    PATH="$(path_without_composer)" run run_gate fast

    [ "$status" -eq 0 ]
    ran artisan
}

@test "a directory without a Composer project reports nothing to check" {
    empty_dir="$fixture/no-project"
    mkdir -p "$empty_dir"
    git init -q "$empty_dir"

    run env PATH="$fake_bin:$PATH" XDG_CONFIG_HOME="$config_home" CLAUDE_PROJECT_DIR="$empty_dir" "$gate" fast

    [ "$status" -eq 3 ]
    [[ "$output" == *'QUALITY_NO_PROJECT'* ]]
}

@test "an unknown check mode shows usage" {
    run run_gate bogus

    [ "$status" -eq 64 ]
    [[ "$output" == *'Usage:'* ]]
}

@test "checking one file requires a path" {
    run run_gate file

    [ "$status" -eq 64 ]
}

@test "checking a missing file explains the problem" {
    run run_gate file "$project/src/DoesNotExist.php"

    [ "$status" -eq 64 ]
    [[ "$output" == *'Not a regular file'* ]]
}

@test "a path excluded from Pint can still be checked by Rector" {
    printf '{"exclude": ["src/Legacy"]}\n' > "$project/pint.json"
    mkdir -p "$project/src/Legacy"
    printf '<?php\n' > "$project/src/Legacy/Old.php"

    run run_gate file "$project/src/Legacy/Old.php"

    [ "$status" -eq 0 ]
    ! ran pint
    ran rector
}

@test "Pint still checks files outside its excluded paths" {
    printf '{"exclude": ["src/Legacy"]}\n' > "$project/pint.json"

    run run_gate file "$project/src/Example.php"

    [ "$status" -eq 0 ]
    ran pint
}

@test "a path denied by Pint can still be checked by Rector" {
    printf '{"notPath": ["tmp"]}\n' > "$project/pint.json"
    mkdir -p "$project/tmp"
    printf '<?php\n' > "$project/tmp/Scratch.php"

    run run_gate file "$project/tmp/Scratch.php"

    [ "$status" -eq 0 ]
    ! ran pint
    ran rector
}

@test "a full check validates and audits dependencies" {
    run run_gate full

    [ "$status" -eq 0 ]
    ran_with_argument composer validate
    ran_with_argument composer audit
}

@test "a fast check validates dependencies without auditing them" {
    run run_gate fast

    [ "$status" -eq 0 ]
    ran_with_argument composer validate
    ! ran_with_argument composer audit
}

@test "a project with Pest and PHPUnit uses Pest" {
    run run_gate fast

    [ "$status" -eq 0 ]
    ran pest
    ! ran phpunit
}

@test "a Pest suite runs in parallel when ParaTest is available" {
    install_tool "$project" paratest

    run run_gate fast

    [ "$status" -eq 0 ]
    ran_with_argument pest --parallel
}

@test "a Pest suite runs normally without ParaTest" {
    run run_gate fast

    [ "$status" -eq 0 ]
    ! ran_with_argument pest --parallel
}

@test "a PHPUnit project uses ParaTest when it is available" {
    rm "$project/vendor/bin/pest"
    install_tool "$project" paratest

    run run_gate fast

    [ "$status" -eq 0 ]
    ran paratest
    ! ran phpunit
}

@test "an Artisan test suite runs in parallel when ParaTest is available" {
    rm "$project/vendor/bin/pest" "$project/vendor/bin/phpunit"
    install_tool "$project" paratest
    cat > "$project/artisan" <<'ARTISAN'
<?php
$tool = 'artisan';
file_put_contents(getenv('QUALITY_TEST_LOG'), "$tool\n", FILE_APPEND);
file_put_contents(getenv('QUALITY_TEST_LOG') . '.args', $tool . ' ' . implode(' ', array_slice($argv, 1)) . "\n", FILE_APPEND);
exit($tool === getenv('QUALITY_FAIL_TOOL') ? 1 : 0);
ARTISAN

    run run_gate fast

    [ "$status" -eq 0 ]
    ran artisan
    ran_with_argument artisan --parallel
}
