source "$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/test_helper.bash"

new_quality_fixture() {
    new_dotfiles_fixture
    fixture="$(cd "$fixture" && pwd -P)"

    hooks_dir="$dotfiles_dir/home/.claude/hooks"
    gate="$hooks_dir/quality-gate.sh"
    settings="$hooks_dir/../settings.json"
    fake_bin="$fixture/bin"
    log="$fixture/tools.log"
    config_home="$fixture/config"
    test_home="$fixture/home"

    mkdir -p "$fake_bin" "$test_home/.claude"
    ln -s "$hooks_dir" "$test_home/.claude/hooks"

    cat > "$fake_bin/tool" <<'TOOL'
#!/usr/bin/env bash
set -u

tool="$(basename -- "$0")"
printf '%s\n' "$tool" >> "$QUALITY_TEST_LOG"
printf '%s %s\n' "$tool" "$*" >> "$QUALITY_TEST_LOG.args"
[[ "$tool" == "${QUALITY_FAIL_TOOL:-}" ]] && exit 1
exit 0
TOOL
    chmod +x "$fake_bin/tool"

    # The real `herd which-php` call in quality-gate.sh takes ~400ms per
    # invocation. This fixture never depends on the Herd-specific interpreter
    # it resolves, and CI has no herd on PATH either, so shadowing it here to
    # fail fast is behavior-equivalent, not a shortcut around real coverage.
    cat > "$fake_bin/herd" <<'TOOL'
#!/usr/bin/env bash
exit 1
TOOL
    chmod +x "$fake_bin/herd"

    cat > "$fake_bin/php-tool" <<'TOOL'
<?php

$tool = basename($argv[0]);
file_put_contents(getenv('QUALITY_TEST_LOG'), "$tool\n", FILE_APPEND);
file_put_contents(getenv('QUALITY_TEST_LOG') . '.args', $tool . ' ' . implode(' ', array_slice($argv, 1)) . "\n", FILE_APPEND);
exit($tool === getenv('QUALITY_FAIL_TOOL') ? 1 : 0);
TOOL
    chmod +x "$fake_bin/php-tool"

    : > "$log"
}

teardown_quality_fixture() {
    teardown_dotfiles_fixture
}

new_project() {
    git_root="$fixture/repo"
    project="$git_root"

    mkdir -p "$project/src" "$project/vendor/bin"
    git init -q "$git_root"
    printf '{}\n' > "$project/composer.json"
    printf '<?php\n' > "$project/src/Example.php"
    printf '# Fixture\n' > "$project/README.md"
}

given_project_with_tools() {
    local tool
    new_project
    for tool in "$@"; do
        install_tool "$project" "$tool"
    done
}

# A Composer project nested below the Git root (e.g. a Laravel app's own
# packages/* package), distinct from a repository-root project.
new_nested_project() {
    git_root="$fixture/repo"
    project="$git_root/packages/example"

    mkdir -p "$project/src" "$project/vendor/bin"
    git init -q "$git_root"
    printf '{}\n' > "$project/composer.json"
    printf '<?php\n' > "$project/src/Example.php"
}

given_nested_project_with_tools() {
    local tool
    new_nested_project
    for tool in "$@"; do
        install_tool "$project" "$tool"
    done
}

given_composer_project_without_quality_tools() {
    new_project
}

given_dirty_project_after_php_edit_with_tools() {
    given_project_with_tools "$@"
    marker="$config_home/claude-quality/runs$project.dirty"
    post_event post-php-edit.sh "$project/src/Example.php"
    [ -e "$marker" ]
    : > "$log"
}

# A second, sibling Composer project inside the same Git root as the current
# $project, dirtied by a PHP edit and left with a failing PHPStan so tests can
# prove multiple nested projects are tracked and gated independently.
given_second_dirty_project_with_failing_phpstan() {
    second_project="$git_root/second"
    second_marker="$config_home/claude-quality/runs$second_project.dirty"
    mkdir -p "$second_project/src" "$second_project/vendor/bin"
    printf '{}\n' > "$second_project/composer.json"
    printf '<?php\n' > "$second_project/src/Example.php"
    install_tool "$second_project" pint
    install_tool "$second_project" rector
    cat > "$second_project/vendor/bin/phpstan" <<'TOOL'
#!/usr/bin/env bash
printf 'phpstan\n' >> "$QUALITY_TEST_LOG"
exit 1
TOOL
    chmod +x "$second_project/vendor/bin/phpstan"
    post_event post-php-edit.sh "$second_project/src/Example.php"
}

given_project_with_artisan_test_runner() {
    new_project
    install_artisan_test_runner
}

commit_project() {
    configure_test_repository "$git_root"
    git -C "$git_root" add --all
    git -C "$git_root" commit -qm fixture
}

install_tool() {
    local project="$1" tool="$2"
    case "$tool" in
        composer) ln -s "$fake_bin/tool" "$fake_bin/composer" ;;
        pest|phpunit|paratest) ln -s "$fake_bin/php-tool" "$project/vendor/bin/$tool" ;;
        *) ln -s "$fake_bin/tool" "$project/vendor/bin/$tool" ;;
    esac
}

run_gate() {
    PATH="$fake_bin:$PATH" \
        XDG_CONFIG_HOME="$config_home" \
        CLAUDE_PROJECT_DIR="$project" \
        CLAUDE_QUALITY_SKIP_TESTS="${CLAUDE_QUALITY_SKIP_TESTS:-}" \
        CLAUDE_QUALITY_SKIP_RECTOR="${CLAUDE_QUALITY_SKIP_RECTOR:-}" \
        QUALITY_TEST_LOG="$log" \
        QUALITY_FAIL_TOOL="${QUALITY_FAIL_TOOL:-}" \
        "$gate" "$@"
}

run_gate_for_project() {
    local selected_project="$1"
    shift

    PATH="$fake_bin:$PATH" \
        XDG_CONFIG_HOME="$config_home" \
        CLAUDE_PROJECT_DIR="$selected_project" \
        QUALITY_TEST_LOG="$log" \
        "$gate" "$@"
}

run_gate_for_project_without_composer() {
    local selected_project="$1"
    shift

    PATH="$(path_without_composer)" \
        XDG_CONFIG_HOME="$config_home" \
        CLAUDE_PROJECT_DIR="$selected_project" \
        QUALITY_TEST_LOG="$log" \
        "$gate" "$@"
}

run_hook() {
    local hook="$1"
    shift

    HOME="$test_home" \
        PATH="$fake_bin:$PATH" \
        XDG_CONFIG_HOME="$config_home" \
        CLAUDE_PROJECT_DIR="$project" \
        CLAUDE_QUALITY_DISABLE="${CLAUDE_QUALITY_DISABLE:-}" \
        CLAUDE_QUALITY_SKIP_TESTS="${CLAUDE_QUALITY_SKIP_TESTS:-}" \
        CLAUDE_QUALITY_SKIP_RECTOR="${CLAUDE_QUALITY_SKIP_RECTOR:-}" \
        QUALITY_TEST_LOG="$log" \
        QUALITY_FAIL_TOOL="${QUALITY_FAIL_TOOL:-}" \
        "$hooks_dir/$hook" "$@"
}

run_quality() {
    HOME="$test_home" \
        PATH="$fake_bin:$PATH" \
        XDG_CONFIG_HOME="$config_home" \
        CLAUDE_PROJECT_DIR="$project" \
        QUALITY_TEST_LOG="$log" \
        zsh -c 'source "$1"; shift; quality "$@"' zsh "$functions_file" "$@"
}

run_quality_status() {
    HOME="$test_home" \
        PATH="$fake_bin:$PATH" \
        XDG_CONFIG_HOME="$config_home" \
        zsh -c 'cd "$1"; source "$2"; quality status' zsh "$project" "$functions_file"
}

post_event() {
    local hook="$1" file="$2"
    jq -nc --arg file "$file" '{tool_input: {file_path: $file}}' | run_hook "$hook"
}

stop_event() {
    local active="$1"
    jq -nc --arg cwd "$project" --argjson active "$active" \
        '{cwd: $cwd, stop_hook_active: $active}' | run_hook require-evidence.sh
}

stop_event_json() {
    printf '%s' "$1" | run_hook require-evidence.sh
}

path_without_composer() {
    local dir="$fixture/minimal-path" tool
    mkdir -p "$dir"
    for tool in bash git jq php dirname basename mkdir date grep sort rm; do
        ln -sf "$(bash -c "command -v $tool")" "$dir/$tool"
    done
    printf '%s' "$dir"
}

given_herd_resolving_to_system_php() {
    local system_php
    system_php="$(command -v php)"

    cat > "$fake_bin/herd" <<HERD
#!/usr/bin/env bash
if [[ "\$1" == "which-php" ]]; then
    echo "$system_php"
    exit 0
fi
exit 1
HERD
    chmod +x "$fake_bin/herd"
}

# Redirects `mktemp -d` into a fixture-owned directory so a test can assert on
# what the gate leaves behind there. macOS's own mktemp ignores $TMPDIR for an
# implicit template, so pointing it at the real system temp dir isn't
# observable from a hermetic test.
given_mktemp_creating_directories_under_fixture() {
    mktemp_tracking_dir="$fixture/mktemp-tracking"
    mkdir -p "$mktemp_tracking_dir"

    cat > "$fake_bin/mktemp" <<MKTEMP
#!/usr/bin/env bash
if [[ "\$1" == "-d" ]]; then
    /usr/bin/mktemp -d "$mktemp_tracking_dir/tmp.XXXXXXXX"
    exit 0
fi
exec /usr/bin/mktemp "\$@"
MKTEMP
    chmod +x "$fake_bin/mktemp"
}

install_artisan_test_runner() {
    cat > "$project/artisan" <<'ARTISAN'
<?php
$tool = 'artisan';
file_put_contents(getenv('QUALITY_TEST_LOG'), "$tool\n", FILE_APPEND);
file_put_contents(getenv('QUALITY_TEST_LOG') . '.args', $tool . ' ' . implode(' ', array_slice($argv, 1)) . "\n", FILE_APPEND);
exit($tool === getenv('QUALITY_FAIL_TOOL') ? 1 : 0);
ARTISAN
}

write_quality_record() {
    local record="$1" root="$2" mode="$3" exit_code="$4"
    mkdir -p "$(dirname -- "$record")"
    jq -n --arg root "$root" --arg mode "$mode" --argjson exit "$exit_code" \
        '{root: $root, mode: $mode, exit: $exit}' > "$record"
}

configure_pint_to_exclude() {
    printf '{"exclude": ["%s"]}\n' "$1" > "$project/pint.json"
}

configure_pint_to_deny() {
    printf '{"notPath": ["%s"]}\n' "$1" > "$project/pint.json"
}

ran() {
    grep -Fxq "$1" "$log"
}

ran_count() {
    grep -Fxc "$1" "$log" || true
}

ran_with_argument() {
    grep -E "^$1( |$)" "$log.args" 2>/dev/null | grep -Fq -- "$2"
}

assert_tool_ran() {
    ran "$1"
}

assert_tool_did_not_run() {
    ! ran "$1" || false
}

assert_tool_ran_with_argument() {
    ran_with_argument "$1" "$2"
}

assert_tool_did_not_run_with_argument() {
    ! ran_with_argument "$1" "$2" || false
}

assert_tool_run_count() {
    [ "$(ran_count "$1")" -eq "$2" ]
}

check_post_edit_hook_is_configured() {
    local hook="$1"
    jq -e --arg command "\"\$HOME/.claude/hooks/$hook\"" \
        'any(.hooks.PostToolUse[]; .matcher == "Write|Edit"
            and any(.hooks[]; .command == $command))' "$settings" >/dev/null
}

check_stop_hook_is_configured() {
    local timeout="$1"
    jq -e --arg command '"$HOME/.claude/hooks/require-evidence.sh"' --argjson timeout "$timeout" \
        'any(.hooks.Stop[]; any(.hooks[];
            .command == $command and .timeout == $timeout))' "$settings" >/dev/null
}

assert_record_value() {
    local record="$1" key="$2" expected="$3"
    [ "$(jq -r ".$key" "$record")" = "$expected" ]
}

assert_record_exit_is_success() {
    [ "$(jq -r .exit "$1")" -eq 0 ]
}

assert_record_exit_is_failure() {
    [ "$(jq -r .exit "$1")" -ne 0 ]
}

assert_output_json_value() {
    local key="$1" expected="$2"
    [ "$(printf '%s' "$output" | jq -r ".$key")" = "$expected" ]
}
