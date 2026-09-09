#!/bin/bash

set -e

repository="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repository"

export TERM="${TERM:-xterm}"

if (( $# == 0 )); then
    set -- -r tests/
fi

# The suite is almost entirely process-spawn wait, not CPU, so run test files
# concurrently. bats needs a parallel backend; rush (Brewfile: rush-parallel) is
# already a dependency, so use it rather than pulling in GNU parallel. Output is
# buffered and released in file order, so the first few seconds look quiet under
# load; that is display lag, not a hang. Set BATS_JOBS=1 to run serially when
# debugging a test that only fails under concurrency.
jobs="${BATS_JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"

exec bats --pretty --timing --jobs "$jobs" --parallel-binary-name rush "$@"
