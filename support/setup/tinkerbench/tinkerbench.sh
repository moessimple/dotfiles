#!/bin/bash

# tinkerbench (https://github.com/moessimple/tinkerbench) is a separate project
# bootstrapped by both install and reconfigure. Existing checkouts are left
# untouched and updated like any other project. Clone and setup are guarded
# separately: composer setup creates `.env`, so an interrupted setup is retried
# on the next run.
step "Setting up tinkerbench.test"

TINKERBENCH_TARGET="$HOME/Code/tinkerbench"

if [ ! -d "$TINKERBENCH_TARGET" ]; then
    git clone git@github.com:moessimple/tinkerbench.git "$TINKERBENCH_TARGET" \
        || error "Could not clone tinkerbench"
fi

if [ ! -f "$TINKERBENCH_TARGET/.env" ]; then
    (cd "$TINKERBENCH_TARGET" && composer setup) || error "Could not set up tinkerbench"
fi

success "tinkerbench.test ready"
