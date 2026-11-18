#!/usr/bin/env bats

load ../../support/test_helper
load ../../support/setup_cleanup_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    target="$dotfiles_dir/support/setup/packages/ollama-models.sh"
}

teardown() {
    teardown_dotfiles_fixture
}

@test "sourcing ollama-models.sh only defines its functions and talks to no Ollama server" {
    # Arrange
    given_fake_ollama_listing ''

    # Act
    run run_setup_script "$target"

    # Assert
    assert_success
    [ -z "$output" ]
    assert_binary_not_called ollama
}

@test "every declared model is pulled" {
    # Arrange
    given_fake_ollama_listing ''

    # Act
    run call_setup_function "$target" install_ollama_models

    # Assert
    assert_success
    assert_binary_called_with ollama "pull qwen3.5:4b-q4_K_M"
    assert_binary_called_with ollama "pull embeddinggemma:latest"
}

@test "an unreachable server skips pulling instead of failing the run" {
    # Arrange
    given_fake_ollama_failing_to_list
    write_fake_binary sleep

    # Act
    run call_setup_function "$target" install_ollama_models

    # Assert
    assert_success
    assert_output_contains "Ollama server is not reachable, skipping models"
    assert_binary_not_called_with_substring ollama "pull"
}

@test "a pulled model not declared in ollama-models.sh is removed" {
    # Arrange
    given_fake_ollama_listing $'qwen3.5:4b-q4_K_M\nllama3.2:latest'

    # Act
    run call_cleanup_function "$target" clean_up_ollama_models

    # Assert
    assert_success
    assert_binary_called_with ollama "rm llama3.2:latest"
    assert_binary_not_called_with_substring ollama "rm qwen3.5:4b-q4_K_M"
}

@test "no undeclared models reports a clean state without removing anything" {
    # Arrange
    given_fake_ollama_listing $'qwen3.5:4b-q4_K_M\nembeddinggemma:latest'

    # Act
    run call_cleanup_function "$target" clean_up_ollama_models

    # Assert
    assert_success
    assert_output_contains "No undeclared Ollama models found"
    assert_binary_not_called_with_substring ollama "rm "
}

@test "a failed read of pulled models skips cleanup instead of removing everything" {
    # Arrange
    given_fake_ollama_failing_to_list
    write_fake_binary sleep

    # Act
    run call_cleanup_function "$target" clean_up_ollama_models

    # Assert
    assert_success
    assert_output_contains "Could not read Ollama models, skipping cleanup"
    assert_binary_not_called_with_substring ollama "rm "
}

@test "models are skipped entirely when ollama is not installed" {
    # Act
    PATH="/usr/bin:/bin" run call_setup_function "$target" install_ollama_models

    # Assert
    assert_success
    assert_output_contains "Ollama is not installed, skipping models"
}

@test "a failed removal is reported while remaining undeclared entries are still removed" {
    given_fake_ollama_listing $'stale-one\nstale-two\nembeddinggemma:latest'
    printf '\nif [[ "$*" == "rm stale-one" ]]; then exit 17; fi\n' >>"$fake_bin/ollama"

    run call_cleanup_function "$target" clean_up_ollama_models

    assert_success
    assert_output_contains "Could not remove stale-one"
    assert_binary_called_with_substring ollama "rm stale-two"
    assert_binary_not_called_with_substring ollama "rm embeddinggemma:latest"
}
