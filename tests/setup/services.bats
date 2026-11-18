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
    run run_setup_script "$dotfiles_dir/support/setup/services.sh"

    # Assert
    assert_success
    assert_file_content "$fixture/var/config.toml" "upgrade_db = true"
    assert_binary_called_with brew "services start meilisearch"
}
