#!/usr/bin/env bats

load ../../support/test_helper
load ../../support/setup_cleanup_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    test_home="$fixture/home"
    mkdir -p "$test_home"
    target="$dotfiles_dir/support/setup/herd-onboarding.sh"
}

teardown() {
    teardown_dotfiles_fixture
}

# Leaves only the fakes and the system tools on PATH, so a Herd installed on the machine running
# the tests cannot end the wait early. The first `sleep` of the wait loop installs the fake CLI,
# the way completing onboarding in the Herd app does.
given_herd_cli_appears_during_the_wait() {
    export PATH="$fake_bin:/usr/bin:/bin"
    write_fake_binary open
    write_fake_binary sleep "printf '#!/bin/bash\n' >'$fake_bin/herd'; chmod +x '$fake_bin/herd'"
}

@test "waiting for Herd's onboarding leaves no variables behind in the calling shell" {
    # Arrange
    given_herd_cli_appears_during_the_wait

    # Act
    run list_variables_left_by_setup_function "$target" herd_onboarding_wait

    # Assert
    assert_success
    assert_output_equals ""
    assert_binary_called_with open "-a Herd"
}
