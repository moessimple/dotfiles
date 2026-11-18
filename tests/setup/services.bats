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

@test "service setup enables Meilisearch database upgrades before starting Meilisearch" {
    # Arrange
    write_fake_binary brew 'if [[ "$*" == "services start meilisearch" ]]; then
    cat "$HOMEBREW_PREFIX/var/config.toml" >"$HOMEBREW_PREFIX/config-at-meilisearch-start"
fi'
    printf 'http_addr = "0.0.0.0:7700"\n' >"$fixture/var/config.toml"

    # Act
    run call_setup_function "$dotfiles_dir/support/setup/services.sh" start_services

    # Assert
    assert_success
    assert_file_content "$fixture/var/config.toml" "upgrade_db = true"
    assert_binary_called_with_args brew services start meilisearch
    assert_file_content "$fixture/config-at-meilisearch-start" "upgrade_db = true"
}

@test "sourcing services does not start services or rewrite their config" {
    printf 'local config\n' >"$fixture/var/config.toml"

    run run_setup_script "$dotfiles_dir/support/setup/services.sh"

    assert_success
    [ -z "$output" ]
    assert_binary_not_called brew
    assert_file_content "$fixture/var/config.toml" "local config"
}

@test "a failed Mailpit start does not prevent Meilisearch or Ollama and fails the final summary" {
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

@test "an unwritable Meilisearch config is reported without preventing service startup" {
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
