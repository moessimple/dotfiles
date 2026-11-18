#!/bin/bash

# Local Ollama models: one chat model and one embedding model. Sized for 16 GB of unified
# memory: macOS gives the GPU roughly 10-11 GB, so anything much larger than ~9B in Q4
# swaps once Herd and a browser are running.
# Interactive use on a base M4 needs a model faster than qwen3.5:9b (~7 tokens/s).
# Pin the GGUF quantization (q4_K_M): Ollama rejects structured output (a JSON schema `format`)
# for the default tag's NVFP4 (MLX) build with 501.
# Each model costs several GB of disk under ~/.ollama/models, check `df -h` before adding one.
# Tags are explicit because clean_up_ollama_models compares them against `ollama list`,
# which always reports a tag (`embeddinggemma` is listed as `embeddinggemma:latest`).
OLLAMA_MODELS=(
    qwen3.5:4b-q4_K_M
    embeddinggemma:latest
)

# The Homebrew service starts `ollama serve` asynchronously (services.sh on install, a
# restart during `brew upgrade` on update), so give it a moment before talking to it.
wait_for_ollama_server() {
    local attempt
    for ((attempt = 0; attempt < 10; attempt++)); do
        ollama list &>/dev/null && return 0
        sleep 1
    done
    return 1
}

# `ollama pull` on an installed model only fetches changed layers, so this is both the
# install and the update step.
install_ollama_models() {
    step "Installing Ollama models"
    if ! command -v ollama &>/dev/null; then
        warn "Ollama is not installed, skipping models"
    elif ! wait_for_ollama_server; then
        warn "Ollama server is not reachable, skipping models (start it with: brew services start ollama)"
    else
        local model
        for model in "${OLLAMA_MODELS[@]}"; do
            ollama pull "$model" || warn "Could not pull $model"
        done
        success "Ollama models processed"
    fi
}

# Removes any pulled model that isn't in OLLAMA_MODELS: a model pulled by hand to try it
# out is gone after the next update unless it is declared here.
clean_up_ollama_models() {
    command -v ollama &>/dev/null || return 0

    step "Checking for undeclared Ollama models"

    local installed
    if ! installed=$(
        set -o pipefail
        ollama list 2>/dev/null | awk 'NR > 1 { print $1 }'
    ); then
        warn "Could not read Ollama models, skipping cleanup"
        return 0
    fi

    local name found_undeclared=0
    while IFS= read -r name; do
        [[ -n "$name" ]] || continue
        printf '%s\n' "${OLLAMA_MODELS[@]}" | grep -qxF "$name" && continue

        found_undeclared=1
        note "Removing undeclared Ollama model: $name (not in ollama-models.sh)"
        ollama rm "$name" || warn "Could not remove $name, remove it manually"
    done <<<"$installed"

    if ((found_undeclared == 0)); then
        success "No undeclared Ollama models found"
    fi
}
