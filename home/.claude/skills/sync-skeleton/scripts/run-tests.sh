#!/usr/bin/env bash
# run-tests.sh - run the project's verification commands so a regression from the
# sync can be told apart from a failure that already existed.
#
# Usage:
#   run-tests.sh <target>                     run every check, print results, exit 0/1
#   run-tests.sh <target> --baseline <file>   record the results to <file>
#   run-tests.sh <target> --compare  <file>   re-run <file>'s commands, flag regressions
#
# Three checks, each discovered independently (first match wins):
#   php_tests     vendor/bin/pest -> vendor/bin/phpunit -> php artisan test -> composer test
#   js_typecheck  package.json script: types -> typecheck -> tsc   ( <pm> run <script> )
#   js_build      package.json script: build                       ( <pm> run build )
#
# php_tests prefers the low-level runner over `composer test` on purpose: Phase 5
# realigns the `test` alias to the kit's stricter body, and the preservation
# check must run the SAME suite before and after, not a newly-stricter gate. The
# JS checks are re-run as recorded: a `build` / `types` body that the toolchain
# swap changed is exactly the signal this check exists to catch.
#
# Result / baseline: one line per check,
#   "<label>\t<pass|fail|skip>\t<command>\t<logfile>".
# Each command's combined output goes to
# ${TMPDIR:-/tmp}/sync-skeleton-tests-<label>.log.
#
# Compare mode re-runs the command each baseline line recorded and prints
# REGRESSION for every label that was `pass` in the baseline and is `fail` now. A
# shared pre-existing failure, or a check the baseline could not discover, is not
# a regression.
#
# No jq: composer / npm script blocks are flat "key": value maps.
#
# Exit codes: 1 a check failed (run) or regressed (compare); 64 bad arguments.

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

labels="php_tests js_typecheck js_build"

log_for() { printf '%s/sync-skeleton-tests-%s.log' "${TMPDIR:-/tmp}" "$1"; }

js_pm() {
    if   [[ -f pnpm-lock.yaml ]];           then echo pnpm
    elif [[ -f bun.lockb || -f bun.lock ]]; then echo bun
    elif [[ -f yarn.lock ]];                then echo yarn
    else                                         echo npm
    fi
}

# True when <file>'s top-level "scripts" object has <key>. Flat block: it opens
# on the "scripts" line and ends at the first line whose first non-space char is }.
scripts_block_has() {
    local file="$1" key="$2"
    [[ -f "$file" ]] || return 1
    awk -v pat="\"$key\"[[:space:]]*:" '
        !inb && /"scripts"[[:space:]]*:/ { inb = 1 }
        inb && /^[[:space:]]*}/          { exit found ? 0 : 1 }
        inb && $0 ~ pat                  { found = 1; exit 0 }
        END                             { exit found ? 0 : 1 }
    ' "$file"
}

discover_php_tests() {
    if   [[ -x vendor/bin/pest ]];             then echo "vendor/bin/pest"
    elif [[ -x vendor/bin/phpunit ]];          then echo "vendor/bin/phpunit"
    elif [[ -f artisan ]];                     then echo "php artisan test"
    elif scripts_block_has composer.json test; then echo "composer test"
    fi
}

discover_js_typecheck() {
    [[ -f package.json ]] || return 0
    local s
    for s in types typecheck tsc; do
        if scripts_block_has package.json "$s"; then
            printf '%s run %s\n' "$(js_pm)" "$s"
            return
        fi
    done
}

discover_js_build() {
    [[ -f package.json ]] || return 0
    scripts_block_has package.json build && printf '%s run build\n' "$(js_pm)"
}

discover_for() {
    case "$1" in
        php_tests)    discover_php_tests ;;
        js_typecheck) discover_js_typecheck ;;
        js_build)     discover_js_build ;;
    esac
}

# Print "<label>\t<state>\t<command>\t<logfile>". With an explicit <command>
# argument, run that; otherwise discover it.
run_check() {
    local label="$1" cmd log
    if [[ $# -ge 2 ]]; then cmd="$2"; else cmd="$(discover_for "$label")"; fi
    if [[ -z "$cmd" ]]; then
        printf '%s\tskip\t\t\n' "$label"
        return
    fi
    log="$(log_for "$label")"
    : > "$log"
    if ( eval "$cmd" ) >"$log" 2>&1; then
        printf '%s\tpass\t%s\t%s\n' "$label" "$cmd" "$log"
    else
        printf '%s\tfail\t%s\t%s\n' "$label" "$cmd" "$log"
    fi
}

state_of() { printf '%s' "$1" | cut -f2; }

baseline_field() {  # <file> <label> <field-number>
    awk -F'\t' -v l="$2" -v n="$3" '$1 == l { print $n; exit }' "$1"
}

case "$mode" in
    run)
        rc=0
        for label in $labels; do
            line="$(run_check "$label")"
            printf '%s\n' "$line"
            [[ "$(state_of "$line")" == "fail" ]] && rc=1
        done
        exit "$rc"
        ;;

    --baseline)
        : > "$ref"
        for label in $labels; do
            run_check "$label" >> "$ref"
        done
        echo "run-tests: baseline recorded at $ref" >&2
        ;;

    --compare)
        [[ -f "$ref" ]] || { echo "run-tests: baseline '$ref' not found" >&2; exit 64; }
        rc=0
        for label in $labels; do
            base_state="$(baseline_field "$ref" "$label" 2)"
            base_cmd="$(baseline_field "$ref" "$label" 3)"
            if [[ -z "$base_state" || "$base_state" == "skip" ]]; then
                printf '%s\tskip\t\t\n' "$label"
                continue
            fi
            line="$(run_check "$label" "$base_cmd")"
            printf '%s\n' "$line"
            if [[ "$base_state" == "pass" && "$(state_of "$line")" == "fail" ]]; then
                echo "REGRESSION: $label passed in the baseline and fails now (log: $(log_for "$label"))" >&2
                rc=1
            fi
        done
        exit "$rc"
        ;;
esac
