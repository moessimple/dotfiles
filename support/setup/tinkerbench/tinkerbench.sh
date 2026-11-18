#!/bin/bash

tinkerbench_setup() {
    # tinkerbench (https://github.com/moessimple/tinkerbench) is a separate project
    # bootstrapped by both install and reconfigure. Existing checkouts are left
    # untouched and updated like any other project. Clone and setup are guarded
    # separately: composer setup creates `.env`, so an interrupted setup is retried
    # on the next run.
    step "Setting up tinkerbench.test"

    TINKERBENCH_TARGET="$HOME/Code/tinkerbench"

    if [[ ! -d "$TINKERBENCH_TARGET" ]] \
        && ! git clone git@github.com:moessimple/tinkerbench.git "$TINKERBENCH_TARGET"; then
        warn "Could not clone tinkerbench"
    elif [[ ! -f "$TINKERBENCH_TARGET/.env" ]] && ! (cd "$TINKERBENCH_TARGET" && composer setup); then
        warn "Could not set up tinkerbench"
    else
        success "tinkerbench.test ready"
    fi
}
