#!/usr/bin/env bash
# run-tests.sh - run the project's test command so a regression from the sync can
# be told apart from a failure that already existed.
#
# Usage:
#   run-tests.sh <target>                     run, print the result, exit 0/1
#   run-tests.sh <target> --baseline <file>   record the result to <file>
#   run-tests.sh <target> --compare  <file>   compare to <file>
#
# The command is discovered, first match wins:
#   composer.json script `test` -> `composer test`
#   else vendor/bin/pest / vendor/bin/phpunit / php artisan test
#
# Result / baseline is one line: "<pass|fail|skip>\t<command>\t<logfile>".
# The command's combined output goes to
# ${TMPDIR:-/tmp}/sync-skeleton-tests.log.
#
# Compare mode: exit 1 and print REGRESSION only if the baseline is `pass` and
# the current run is `fail`. A shared pre-existing failure is not a regression.
#
# No jq: the composer script block is a flat "key": value map.
#
# Exit codes: 1 the run failed (run) or regressed (compare); 64 bad arguments.

set -uo pipefail

target="${1:-}"
mode="${2:-run}"
ref="${3:-}"

if [[ -z "$target" || ! -d "$target" ]]; then
    echo "Usage: run-tests.sh <target> [--baseline <file> | --compare <file>]" >&2
    exit 64
fi
case "$mode" in
    run) ;;
    --baseline|--compare) [[ -n "$ref" ]] || { echo "run-tests: $mode needs a file" >&2; exit 64; } ;;
    *) echo "run-tests: unknown option '$mode'" >&2; exit 64 ;;
esac

cd "$target"
log="${TMPDIR:-/tmp}/sync-skeleton-tests.log"

# True when composer.json has a "scripts" object with a "test" key. Flat block:
# ends at the first line whose first non-space character is }.
has_composer_test() {
    [[ -f composer.json ]] || return 1
    awk '
        !inb && /"scripts"[[:space:]]*:/ { inb = 1; next }
        inb && /^[[:space:]]*}/          { exit found ? 0 : 1 }
        inb && /"test"[[:space:]]*:/     { found = 1; exit 0 }
        END                             { exit found ? 0 : 1 }
    ' composer.json
}

discover() {
    if   has_composer_test;            then echo "composer test"
    elif [[ -x vendor/bin/pest ]];     then echo "vendor/bin/pest"
    elif [[ -x vendor/bin/phpunit ]];  then echo "vendor/bin/phpunit"
    elif [[ -f artisan ]];             then echo "php artisan test"
    fi
}

run_once() {
    local cmd; cmd="$(discover)"
    if [[ -z "$cmd" ]]; then
        printf 'skip\t\t\n'
        return
    fi
    : > "$log"
    if ( eval "$cmd" ) >"$log" 2>&1; then
        printf 'pass\t%s\t%s\n' "$cmd" "$log"
    else
        printf 'fail\t%s\t%s\n' "$cmd" "$log"
    fi
}

result="$(run_once)"
state="${result%%$'\t'*}"

case "$mode" in
    run)
        printf '%s\n' "$result"
        [[ "$state" == "fail" ]] && exit 1
        exit 0
        ;;
    --baseline)
        printf '%s\n' "$result" > "$ref"
        echo "run-tests: baseline recorded at $ref" >&2
        ;;
    --compare)
        [[ -f "$ref" ]] || { echo "run-tests: baseline '$ref' not found" >&2; exit 64; }
        printf '%s\n' "$result"
        base_state="$(cut -f1 "$ref")"
        if [[ "$base_state" == "pass" && "$state" == "fail" ]]; then
            echo "REGRESSION: the test command passed in the baseline and fails now (log: $log)" >&2
            exit 1
        fi
        exit 0
        ;;
esac
