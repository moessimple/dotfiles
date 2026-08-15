#!/bin/bash

set -e

repository="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repository"

if (( $# == 0 )); then
    set -- -r tests/
fi

exec bats --pretty --timing "$@"
