#!/bin/bash

# Output helpers for the entry points in bin/.
# The other setup scripts do not source this file: their tests stub these helpers first.

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

DOTFILES_PROBLEMS=()

step() {
    echo ""
    echo -e "${BLUE}➜${NC} $1"
}
success() { echo -e "${GREEN}✓${NC} $1"; }
# Information that needs no action to complete the run.
note() { echo -e "${BLUE}ℹ${NC} $1"; }
# A step that could not be completed. The run goes on, and finish reports it again.
warn() {
    DOTFILES_PROBLEMS+=("$1")
    echo -e "${YELLOW}⚠${NC} $1" >&2
}
error() {
    echo -e "${RED}✗${NC} $1" >&2
    exit 1
}

# Ends an entry point. Prints <message> when no step warned; otherwise lists every warning and
# exits 1, the way `brew bundle` finishes after failed installs, so a problem in the middle of a
# long run is neither missed nor reported as success.
finish() {
    echo ""
    if ((${#DOTFILES_PROBLEMS[@]} == 0)); then
        success "$1"
        return 0
    fi

    echo -e "${RED}✗${NC} Finished with ${#DOTFILES_PROBLEMS[@]} problem(s):" >&2
    local problem
    for problem in "${DOTFILES_PROBLEMS[@]}"; do
        echo "  • $problem" >&2
    done
    exit 1
}
