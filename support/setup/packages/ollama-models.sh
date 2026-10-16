#!/bin/bash

# Local Ollama models: one chat model and one embedding model. Sized for 16 GB of unified
# memory: macOS gives the GPU roughly 10-11 GB, so anything much larger than ~9B in Q4
# swaps once Herd and a browser are running.
# qwen3.5:9b fits but generates only ~7 tokens/s on a base M4, too slow to iterate with.
# Each model costs several GB of disk under ~/.ollama/models, check `df -h` before adding one.
# Tags are explicit because ollama_models_cleanup compares them against `ollama list`,
# which always reports a tag (`embeddinggemma` is listed as `embeddinggemma:latest`).
OLLAMA_MODELS=(
    qwen3.5:4b
    embeddinggemma:latest
)

# The Homebrew service starts `ollama serve` asynchronously (configure.sh on install, a
# restart during `brew upgrade` on update), so give it a moment before talking to it.
_ollama_wait_for_server() {
    local attempt
    for attempt in 1 2 3 4 5 6 7 8 9 10; do
        ollama list &>/dev/null && return 0
        sleep 1
    done
    return 1
}

# `ollama pull` on an installed model only fetches changed layers, so this is both the
# install and the update step.
step "Installing Ollama models"
if ! command -v ollama &>/dev/null; then
    warn "Ollama is not installed, skipping models"
elif ! _ollama_wait_for_server; then
    warn "Ollama server is not reachable, skipping models (start it with: brew services start ollama)"
else
    for model in "${OLLAMA_MODELS[@]}"; do
        ollama pull "$model" || warn "Could not pull $model"
    done
    success "Ollama models processed"
fi

# Removes any pulled model that isn't in OLLAMA_MODELS: a model pulled by hand to try it
# out is gone after the next update unless it is declared here.
ollama_models_cleanup() {
    command -v ollama &>/dev/null || return 0

    step "Checking for undeclared Ollama models"

    # pipefail, and the assignment kept out of `local`, so an unreachable server surfaces
    # instead of looking like an empty list and reporting a green run over a broken one.
    local installed
    if ! installed=$(set -o pipefail; ollama list 2>/dev/null | awk 'NR > 1 { print $1 }'); then
        warn "Could not read Ollama models, skipping cleanup"
        return 0
    fi

    local name found_undeclared=0
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        if ! printf '%s\n' "${OLLAMA_MODELS[@]}" | grep -qxF "$name"; then
            found_undeclared=1
            warn "Removing undeclared Ollama model: $name (not in ollama-models.sh)"
            ollama rm "$name" || warn "Could not remove $name, remove it manually"
        fi
    done <<< "$installed"

    # An `if`, not `&&`, which would return 1 after a removal and trip `set -e` in bin/update.sh
    if [ "$found_undeclared" -eq 0 ]; then
        success "No undeclared Ollama models found"
    fi
}
