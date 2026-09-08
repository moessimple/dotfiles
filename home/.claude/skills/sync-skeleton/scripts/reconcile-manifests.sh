#!/usr/bin/env bash
# reconcile-manifests.sh - regenerate composer.lock and the JS lockfile after
# the agent has applied the plan-manifest.sh directives to composer.json /
# package.json. The agent must have already agreed to run this.
#
# Usage: reconcile-manifests.sh <target>
#
# - `composer update --lock` when composer.json + composer.lock both exist
#   (re-solves only what the manifest edits require).
# - Detects the JS package manager from the lockfile and runs `<pm> install`.
#   On failure (typically ERESOLVE after a major bump) removes node_modules and
#   the lockfile, then retries once. The recovery is announced on stderr.
#
# Exit codes: 1 a regeneration step failed even after recovery; 64 bad arguments.

set -uo pipefail

target="${1:-}"
if [[ -z "$target" || ! -d "$target" ]]; then
    echo "Usage: reconcile-manifests.sh <target>" >&2
    exit 64
fi
cd "$target"

js_pm() {
    if   [[ -f pnpm-lock.yaml ]];           then echo pnpm
    elif [[ -f bun.lockb || -f bun.lock ]]; then echo bun
    elif [[ -f yarn.lock ]];                then echo yarn
    else                                         echo npm
    fi
}

js_lock() {
    if   [[ -f pnpm-lock.yaml ]]; then echo pnpm-lock.yaml
    elif [[ -f bun.lockb ]];      then echo bun.lockb
    elif [[ -f bun.lock ]];       then echo bun.lock
    elif [[ -f yarn.lock ]];      then echo yarn.lock
    else                               echo package-lock.json
    fi
}

status=0

if [[ -f composer.json && -f composer.lock ]]; then
    echo "==> composer update --lock --no-interaction" >&2
    composer update --lock --no-interaction || status=1
fi

if [[ -f package.json ]]; then
    pm="$(js_pm)"
    lock="$(js_lock)"
    echo "==> $pm install" >&2
    if ! "$pm" install; then
        echo "==> '$pm install' failed; removing node_modules + $lock and retrying" >&2
        rm -rf node_modules "$lock"
        "$pm" install || status=1
    fi
fi

exit "$status"
