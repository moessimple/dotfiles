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

@test "Ollama installation pulls the declared language and embedding models" {
    # Arrange
    given_fake_ollama_listing ''

    # Act
    run call_setup_function "$target" install_ollama_models

    # Assert
    assert_success
    assert_binary_called_with ollama "pull qwen3.5:4b-q4_K_M"
    assert_binary_called_with ollama "pull embeddinggemma:latest"
}

@test "Ollama installation warns and pulls no models when the server remains unreachable" {
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

@test "Ollama cleanup reports a clean state when all pulled models are declared" {
    # Arrange
    given_fake_ollama_listing $'qwen3.5:4b-q4_K_M\nembeddinggemma:latest'

    # Act
    run call_cleanup_function "$target" clean_up_ollama_models

    # Assert
    assert_success
    assert_output_contains "No undeclared Ollama models found"
    assert_binary_not_called_with_substring ollama "rm "
}

@test "Ollama cleanup warns and removes no models when the model list cannot be read" {
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

@test "Ollama cleanup reports a failed removal of stale-one and continues with stale-two" {
    given_fake_ollama_listing $'stale-one\nstale-two\nembeddinggemma:latest'
    printf '\nif [[ "$*" == "rm stale-one" ]]; then exit 17; fi\n' >>"$fake_bin/ollama"

    run call_cleanup_function "$target" clean_up_ollama_models

    assert_success
    assert_output_contains "Could not remove stale-one"
    assert_binary_called_with_substring ollama "rm stale-two"
    assert_binary_not_called_with_substring ollama "rm embeddinggemma:latest"
}
