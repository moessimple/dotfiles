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

@test "every declared model is pulled" {
    # Arrange
    given_fake_ollama_listing ''

    # Act
    run run_setup_script "$target"

    # Assert
    assert_success
    assert_binary_called_with ollama "pull qwen3.5:4b"
    assert_binary_called_with ollama "pull embeddinggemma:latest"
}

@test "an unreachable server skips pulling instead of failing the run" {
    # Arrange
    given_fake_ollama_failing_to_list
    write_fake_binary sleep

    # Act
    run run_setup_script "$target"

    # Assert
    assert_success
    assert_output_contains "Ollama server is not reachable, skipping models"
    assert_binary_not_called_with_substring ollama "pull"
}

@test "a pulled model not declared in ollama-models.sh is removed" {
    # Arrange
    given_fake_ollama_listing $'qwen3.5:4b\nllama3.2:latest'

    # Act
    run call_cleanup_function "$target" ollama_models_cleanup

    # Assert
    assert_success
    assert_binary_called_with ollama "rm llama3.2:latest"
    assert_binary_not_called_with_substring ollama "rm qwen3.5:4b"
}

@test "no undeclared models reports a clean state without removing anything" {
    # Arrange
    given_fake_ollama_listing $'qwen3.5:4b\nembeddinggemma:latest'

    # Act
    run call_cleanup_function "$target" ollama_models_cleanup

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
    run call_cleanup_function "$target" ollama_models_cleanup

    # Assert
    assert_success
    assert_output_contains "Could not read Ollama models, skipping cleanup"
    assert_binary_not_called_with_substring ollama "rm "
}

@test "models are skipped entirely when ollama is not installed" {
    # Act
    PATH="/usr/bin:/bin" run run_setup_script "$target"

    # Assert
    assert_success
    assert_output_contains "Ollama is not installed, skipping models"
}
