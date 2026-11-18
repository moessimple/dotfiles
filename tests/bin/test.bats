#!/usr/bin/env bats

load ../support/test_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    export TEST_INTERPRETER_RECORD="$fixture/interpreter-used"
    write_fake_binary bats 'printf "%s\n" "$BASH_VERSION"
command -v bash >"$TEST_INTERPRETER_RECORD"'
}

teardown() {
    teardown_dotfiles_fixture
}

@test "bin/test.sh uses Bash 3.2, forwards the selected test file, and removes its temporary interpreter" {
    BATS_JOBS=2 run "$dotfiles_dir/bin/test.sh" tests/functions/pf.bats

    assert_success
    assert_output_contains "3.2."
    assert_binary_called_with_args bats --pretty --timing --jobs 2 --parallel-binary-name rush tests/functions/pf.bats
    local temporary_interpreter
    temporary_interpreter="$(cat "$TEST_INTERPRETER_RECORD")"
    [ -n "$temporary_interpreter" ]
    assert_path_does_not_exist "$temporary_interpreter"
}

@test "bin/test.sh selects all tests without arguments and preserves exit status 42 from Bats" {
    write_fake_binary bats 'command -v bash >"$TEST_INTERPRETER_RECORD"; exit 42'

    BATS_JOBS=1 run "$dotfiles_dir/bin/test.sh"

    assert_status 42
    assert_binary_called_with_args bats --pretty --timing --jobs 1 --parallel-binary-name rush -r tests/
    local temporary_interpreter
    temporary_interpreter="$(cat "$TEST_INTERPRETER_RECORD")"
    [ -n "$temporary_interpreter" ]
    assert_path_does_not_exist "$temporary_interpreter"
}
