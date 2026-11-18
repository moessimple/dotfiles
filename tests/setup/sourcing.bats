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
    # Act
    run env HOME="$test_home" /bin/bash -ec 'source "$1/support/setup/output.sh"; previous_path="$PATH"; source "$1/support/setup/herd/herd-onboarding.sh"; [[ "$PATH" == "$previous_path" ]]' bash "$dotfiles_dir"

    # Assert
    assert_success
    [ -z "$output" ]
    assert_binary_not_called herd
}

@test "sourcing Herd debug ini setup does not configure PHP" {
    # Act
    run run_setup_script "$dotfiles_dir/support/setup/herd/herd-xdebug.sh"

    # Assert
    assert_success
    [ -z "$output" ]
    assert_binary_not_called herd
}

@test "sourcing tinkerbench setup does not clone or configure a project" {
    # Act
    run run_setup_script "$dotfiles_dir/support/setup/tinkerbench.sh"

    # Assert
    assert_success
    [ -z "$output" ]
    assert_binary_not_called git
    assert_binary_not_called composer
}

@test "all setup files load successfully and silently with an empty PATH" {
    # Arrange
    mkdir -p "$fixture/empty-bin"
    : >"$fixture/source-report"

    # Act: source every setup file and record any output or failure.
    local file
    for file in "$dotfiles_dir"/support/setup/*.sh "$dotfiles_dir"/support/setup/*/*.sh; do
        env HOME="$test_home" PATH="$fixture/empty-bin" /bin/bash -ec 'source "$1"' bash "$file" \
            >>"$fixture/source-report" 2>&1 || echo "failed: $file" >>"$fixture/source-report"
    done

    # Assert
    assert_file_content "$fixture/source-report" ""
}

@test "sourcing home-directories leaves existing directories untouched" {
    # Arrange
    mkdir -p "$test_home/.claude/skills"
    touch "$test_home/.claude/skills/local-skill"

    # Act
    run env HOME="$test_home" /bin/bash -c 'source "$1"' bash \
        "$dotfiles_dir/support/setup/home-directories.sh"

    # Assert
    assert_success
    [ -z "$output" ]
    assert_file_exists "$test_home/.claude/skills/local-skill"
    assert_path_does_not_exist "$test_home/Screenshots"
}

@test "sourcing dotfile-links leaves existing files untouched" {
    # Arrange
    printf 'local aliases\n' >"$test_home/.aliases"

    # Act
    run env HOME="$test_home" /bin/bash -c 'source "$1"' bash \
        "$dotfiles_dir/support/setup/dotfile-links.sh"

    # Assert
    assert_success
    [ -z "$output" ]
    [ ! -L "$test_home/.aliases" ]
    [ "$(cat "$test_home/.aliases")" = "local aliases" ]
}
