#!/usr/bin/env bats

load ../support/test_helper
load ../support/setup_cleanup_helper

setup() {
    new_dotfiles_fixture
    test_home="$fixture/home"
    mkdir -p "$test_home"
    given_fake_bin_on_path
    write_fake_binary herd
    write_fake_binary git 'exit 1'
    write_fake_binary composer
    export HERD_RESOURCES_DIR="$fixture/herd-resources"
}

teardown() {
    teardown_dotfiles_fixture
}

@test "sourcing Herd onboarding does not change PATH or start onboarding" {
    run env HOME="$test_home" /bin/bash -ec 'source "$1/support/setup/output.sh"; previous_path="$PATH"; source "$1/support/setup/herd-onboarding.sh"; [[ "$PATH" == "$previous_path" ]]' bash "$dotfiles_dir"
    assert_success
    [ -z "$output" ]
    assert_binary_not_called herd
}

@test "sourcing Herd debug ini setup does not configure PHP" {
    run run_setup_script "$dotfiles_dir/support/setup/herd-debug-ini.sh"
    assert_success
    [ -z "$output" ]
    assert_binary_not_called herd
}

@test "sourcing tinkerbench setup does not clone or configure a project" {
    run run_setup_script "$dotfiles_dir/support/setup/tinkerbench/tinkerbench.sh"
    assert_success
    [ -z "$output" ]
    assert_binary_not_called git
    assert_binary_not_called composer
}

@test "every setup file can be sourced without external commands or output" {
    mkdir -p "$fixture/empty-bin"
    local file
    for file in "$dotfiles_dir"/support/setup/*.sh "$dotfiles_dir"/support/setup/*/*.sh; do
        run env HOME="$test_home" PATH="$fixture/empty-bin" /bin/bash -ec 'source "$1"' bash "$file"
        assert_success
        [ -z "$output" ]
    done
}
