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
    project="$git_root/nested"

    mkdir -p "$project/src" "$project/vendor/bin"
    git init -q "$git_root"
    printf '{}\n' > "$project/composer.json"
    printf '<?php\n' > "$project/src/Example.php"
    printf '# Fixture\n' > "$project/README.md"
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

ran() {
    grep -Fxq "$1" "$log"
}

ran_count() {
    grep -Fxc "$1" "$log" || true
}

ran_with_argument() {
    grep -E "^$1( |$)" "$log.args" 2>/dev/null | grep -Fq -- "$2"
}
