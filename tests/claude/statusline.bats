#!/usr/bin/env bats

load ../support/test_helper

setup() {
    new_dotfiles_fixture
    target="$dotfiles_dir/home/.claude/statusline.sh"
}

teardown() {
    teardown_dotfiles_fixture
}

assert_context_display() {
    local percentage="$1" color="$2" terminal_color
    case "$color" in
        green) terminal_color=32 ;;
        yellow) terminal_color=33 ;;
        red) terminal_color=31 ;;
        *) return 1 ;;
    esac
    assert_output_equals "$(printf '\033[01;36mproject\033[00m | ctx: \033[01;%sm%s%%\033[00m' "$terminal_color" "$percentage")"
}

@test "context usage below 40 percent is rounded down and displayed in green" {
    # Act
    run /bin/bash "$target" <<<'{"workspace":{"current_dir":"/Code/project"},"context_window":{"used_percentage":39.9}}'

    # Assert
    assert_success
    assert_context_display 39 green
}

@test "context usage at 40 percent is displayed in yellow" {
    # Act
    run /bin/bash "$target" <<<'{"workspace":{"current_dir":"/Code/project"},"context_window":{"used_percentage":40}}'

    # Assert
    assert_success
    assert_context_display 40 yellow
}

@test "context usage below 60 percent is rounded down and remains yellow" {
    # Act
    run /bin/bash "$target" <<<'{"workspace":{"current_dir":"/Code/project"},"context_window":{"used_percentage":59.9}}'

    # Assert
    assert_success
    assert_context_display 59 yellow
}

@test "context usage at 60 percent is displayed in red" {
    # Act
    run /bin/bash "$target" <<<'{"workspace":{"current_dir":"/Code/project"},"context_window":{"used_percentage":60}}'

    # Assert
    assert_success
    assert_context_display 60 red
}

@test "the status line displays zero percent when context use is missing" {
    # Act
    run /bin/bash "$target" <<<'{"workspace":{"current_dir":"/Code/project"}}'

    # Assert
    assert_success
    assert_context_display 0 green
}

@test "the status line still renders when its input cannot be parsed" {
    # Act
    run --separate-stderr /bin/bash "$target" <<<'invalid JSON'

    # Assert
    assert_success
    assert_output_contains "| ctx:"
}
