#!/usr/bin/env bats

load ../support/test_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    write_fake_binary bats 'printf "%s\n" "$BASH_VERSION"
command -v bash'
}

teardown() {
    teardown_dotfiles_fixture
}

@test "the test runner uses macOS Bash and forwards explicit test arguments" {
    BATS_JOBS=2 run "$dotfiles_dir/bin/test.sh" tests/functions/pf.bats

    assert_success
    assert_output_contains "3.2."
    assert_binary_called_with_args bats --pretty --timing --jobs 2 --parallel-binary-name rush tests/functions/pf.bats
    assert_path_does_not_exist "${lines[1]}"
}

@test "the test runner selects the complete suite and preserves a failing Bats status" {
    write_fake_binary bats 'command -v bash; exit 42'

    BATS_JOBS=1 run "$dotfiles_dir/bin/test.sh"

    assert_status 42
    assert_binary_called_with_args bats --pretty --timing --jobs 1 --parallel-binary-name rush -r tests/
    assert_path_does_not_exist "$output"
}
