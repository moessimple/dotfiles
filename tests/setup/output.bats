#!/usr/bin/env bats

load ../support/test_helper

setup() {
    new_dotfiles_fixture
    output_file="$dotfiles_dir/support/setup/output.sh"
}

teardown() {
    teardown_dotfiles_fixture
}

@test "a step is set off from the previous output by a blank line" {
    # Act
    run bash -c 'source "$1"; echo previous; step "Next step"' bash "$output_file"

    # Assert
    assert_success
    assert_output_contains $'previous\n\n'
    assert_output_contains "Next step"
}

@test "an error stops the script with a failure" {
    # Act
    run --separate-stderr bash -c 'source "$1"; error "Broken"; echo "not reached"' bash "$output_file"

    # Assert
    assert_failure
    assert_stderr_contains "Broken"
    assert_output_does_not_contain "not reached"
}

@test "a run without warnings finishes with its success message" {
    # Act
    run bash -c 'source "$1"; finish "All done"' bash "$output_file"

    # Assert
    assert_success
    assert_output_contains "All done"
}

@test "a run with warnings goes on, then lists every warning on stderr and fails" {
    # Act
    run --separate-stderr bash -c 'source "$1"; warn "First problem"; echo "still running"; warn "Second problem"; finish "All done"' bash "$output_file"

    # Assert
    assert_failure
    assert_output_contains "still running"
    assert_output_does_not_contain "All done"
    assert_stderr_contains "Finished with 2 problem(s):"
    assert_stderr_contains "  • First problem"
    assert_stderr_contains "  • Second problem"
}

@test "a note is shown without counting as a problem" {
    # Act
    run bash -c 'source "$1"; note "Restart your terminal"; finish "All done"' bash "$output_file"

    # Assert
    assert_success
    assert_output_contains "Restart your terminal"
    assert_output_contains "All done"
}
