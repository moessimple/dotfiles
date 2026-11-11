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
    run bash -c 'source "$1"; error "Broken"; echo "not reached"' bash "$output_file"

    # Assert
    assert_failure
    assert_output_contains "Broken"
    assert_output_does_not_contain "not reached"
}
