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
    if [[ -n "${runner_pid:-}" ]]; then
        kill -TERM -- "-$runner_pid" 2>/dev/null || true
        wait "$runner_pid" 2>/dev/null || true
    fi
    teardown_dotfiles_fixture
}

@test "bin/test.sh uses the repository Bash 3.2 link and forwards the selected test file" {
    BATS_JOBS=2 run "$dotfiles_dir/bin/test.sh" tests/functions/pf.bats

    assert_success
    assert_output_contains "3.2."
    assert_binary_called_with_args bats --pretty --timing --jobs 2 --parallel-binary-name rush tests/functions/pf.bats
    assert_file_content "$TEST_INTERPRETER_RECORD" "$dotfiles_dir/support/test-shell/bash"
    [ "$(readlink "$dotfiles_dir/support/test-shell/bash")" = /bin/bash ]
}

given_bats_waiting_for_cancellation() {
    export TEST_BATS_PID="$fixture/bats-pid"
    write_fake_binary bats 'command -v bash >"$TEST_INTERPRETER_RECORD"
printf "%s\n" "$$" >"$TEST_BATS_PID"
exec /bin/sleep 5'
}

start_test_runner() {
    # Isolate cleanup and restore SIGINT, which the parallel backend can ignore.
    set -m
    python3 -c '
import os, signal, sys
signal.signal(signal.SIGINT, signal.SIG_DFL)
os.execv(sys.argv[1], sys.argv[1:])
' "$dotfiles_dir/bin/test.sh" >"$fixture/runner-output" 2>&1 3>&- &
    runner_pid="$!"
    set +m
    local attempt
    for attempt in {1..100}; do
        if [[ -s "$TEST_BATS_PID" ]]; then
            return 0
        fi
        /bin/sleep 0.05
    done
    return 1
}

@test "SIGTERM to the runner PID terminates Bats with status 143" {
    given_bats_waiting_for_cancellation
    start_test_runner

    kill -TERM "$runner_pid"
    local runner_status=0
    wait "$runner_pid" || runner_status="$?"

    [ "$runner_status" -eq 143 ]
    ! kill -0 "$(cat "$TEST_BATS_PID")" 2>/dev/null || false
    [ "$(cat "$TEST_BATS_PID")" -eq "$runner_pid" ]
}

@test "SIGINT to the runner PID terminates Bats with status 130" {
    given_bats_waiting_for_cancellation
    start_test_runner

    kill -INT "$runner_pid"
    local runner_status=0
    wait "$runner_pid" || runner_status="$?"

    [ "$runner_status" -eq 130 ]
    ! kill -0 "$(cat "$TEST_BATS_PID")" 2>/dev/null || false
    [ "$(cat "$TEST_BATS_PID")" -eq "$runner_pid" ]
}

@test "bin/test.sh selects all tests without arguments and preserves exit status 42 from Bats" {
    write_fake_binary bats 'command -v bash >"$TEST_INTERPRETER_RECORD"; exit 42'

    BATS_JOBS=1 run "$dotfiles_dir/bin/test.sh"

    assert_status 42
    assert_binary_called_with_args bats --pretty --timing --jobs 1 --parallel-binary-name rush -r tests/
    assert_file_content "$TEST_INTERPRETER_RECORD" "$dotfiles_dir/support/test-shell/bash"
}
