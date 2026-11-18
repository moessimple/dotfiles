#!/usr/bin/env bats

load ../../../support/test_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path

    script="$dotfiles_dir/home/.claude/skills/php-lsp-herd/bin/intelephense-herd"

    herd_php="$fixture/herd/8.4/php"
    mkdir -p "$(dirname "$herd_php")"
    printf '#!/usr/bin/env bash\necho herd-php-8.4\n' >"$herd_php"
    chmod +x "$herd_php"

    write_fake_binary herd "[ \"\$1\" = which-php ] && printf '%s\\n' '$herd_php'"
    write_fake_binary intelephense 'printf "args:%s\n" "$*"; php'

    export TMPDIR="$fixture/tmp"
    mkdir -p "$TMPDIR"
}

teardown() {
    teardown_dotfiles_fixture
}

given_tmpdir_is_a_file() {
    export TMPDIR="$fixture/tmp-file"
    : >"$TMPDIR"
}

@test "Intelephense resolves PHP from Herd when a project-specific PHP binary is available" {
    # Act
    run "$script" --stdio

    # Assert
    assert_success
    assert_output_contains "args:--stdio"
    assert_output_contains "herd-php-8.4"
}

@test "relaunching reuses one shim directory instead of leaking a new one each time" {
    # Act
    "$script" --stdio
    "$script" --stdio
    "$script" --stdio

    # Assert
    shopt -s nullglob
    local temp_entries=("$TMPDIR"/*)
    [ "${#temp_entries[@]}" -eq 1 ]
}

@test "an unavailable Herd PHP falls back to PHP already on PATH" {
    write_fake_binary herd 'exit 1'
    write_fake_binary php 'echo existing-php'

    run "$script" --stdio

    assert_success
    assert_output_contains "args:--stdio"
    assert_output_contains "existing-php"
}

@test "a shim directory that cannot be created falls back to PHP already on PATH" {
    # Arrange
    write_fake_binary php 'echo existing-php'
    given_tmpdir_is_a_file

    # Act
    run "$script" --stdio

    # Assert
    assert_success
    assert_output_contains "args:--stdio"
    assert_output_contains "existing-php"
}
