#!/usr/bin/env bats

load ../support/test_helper
load ../support/setup_cleanup_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    write_fake_binary brew
    mkdir -p "$fixture/var"
}

teardown() {
    teardown_dotfiles_fixture
}

@test "meilisearch is started with a config.toml that upgrades its database in place" {
    # Arrange
    printf 'http_addr = "0.0.0.0:7700"\n' >"$fixture/var/config.toml"

    # Act
    run call_setup_function "$dotfiles_dir/support/setup/services.sh" start_services

    # Assert
    assert_success
    assert_file_content "$fixture/var/config.toml" "upgrade_db = true"
    assert_binary_called_with brew "services start meilisearch"
}

@test "sourcing services does not start services or rewrite their config" {
    printf 'local config\n' >"$fixture/var/config.toml"

    run run_setup_script "$dotfiles_dir/support/setup/services.sh"

    assert_success
    [ -z "$output" ]
    assert_binary_not_called brew
    assert_file_content "$fixture/var/config.toml" "local config"
}

@test "a failed service start does not prevent other services and fails the final summary" {
    write_fake_binary brew 'if [[ "$3" == mailpit ]]; then exit 17; fi'

    run env HOMEBREW_PREFIX="$fixture" /bin/bash -ec '
        source "$1/support/setup/output.sh"
        source "$1/support/setup/services.sh"
        start_services
        finish "Setup complete"
    ' bash "$dotfiles_dir"

    assert_status 1
    assert_binary_called_with_args brew services start meilisearch
    assert_binary_called_with_args brew services start ollama
    assert_output_contains "Could not start mailpit"
    assert_output_contains "Finished with 1 problem(s):"
    assert_output_does_not_contain "Setup complete"
}

@test "an unwritable service config is reported while the remaining services are started" {
    mkdir "$fixture/var/config.toml"

    run env HOMEBREW_PREFIX="$fixture" /bin/bash -ec '
        source "$1/support/setup/output.sh"
        source "$1/support/setup/services.sh"
        start_services
        finish "Setup complete"
    ' bash "$dotfiles_dir"

    assert_status 1
    assert_binary_called_with_args brew services start meilisearch
    assert_binary_called_with_args brew services start ollama
    assert_output_contains "Could not write the Meilisearch config.toml"
    assert_output_does_not_contain "Setup complete"
}
