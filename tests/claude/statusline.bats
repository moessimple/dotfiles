#!/usr/bin/env bats

load ../support/test_helper

setup() {
    new_dotfiles_fixture
    target="$dotfiles_dir/home/.claude/statusline.sh"
}

teardown() {
    teardown_dotfiles_fixture
}

@test "the status line floors context use and changes colors at 40 and 60 percent" {
    local percentage color whole
    while read -r percentage color whole; do
        run /bin/bash "$target" <<<"{\"workspace\":{\"current_dir\":\"/Code/a project\"},\"context_window\":{\"used_percentage\":$percentage}}"

        assert_success
        assert_output_equals "$(printf '\033[01;36ma project\033[00m | ctx: \033[01;%sm%s%%\033[00m' "$color" "$whole")"
    done <<'CASES'
39.9 32 39
40 33 40
59.9 33 59
60 31 60
CASES
}

@test "the status line defaults missing context use to zero" {
    run /bin/bash "$target" <<<'{"workspace":{"current_dir":"/Code/project"}}'

    assert_success
    assert_colorless_output_contains "project | ctx: 0%"
}

@test "the status line still renders when its input cannot be parsed" {
    run --separate-stderr /bin/bash "$target" <<<'invalid JSON'

    assert_success
    assert_output_contains "| ctx:"
}
