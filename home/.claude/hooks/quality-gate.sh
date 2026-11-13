#!/usr/bin/env bash
#
# Global dispatcher for the project quality gate.
#
# Modes: file checks one edited file, fast checks changes since the last clean
# run, and full checks the whole project. CLAUDE_QUALITY_SKIP_RECTOR skips
# Rector in file and fast; CLAUDE_QUALITY_SKIP_TESTS skips tests in fast. Full
# ignores both. Projects set these variables in .claude/settings.local.json;
# see README.md for usage.
#
# Tools are detected per project and run with the project's own configuration.
# Only installed vendor binaries and `artisan` are executed, the trust boundary
# `composer install` already crossed, plus the global Composer for validation
# and, in full mode, auditing.

set -u

source "$(dirname -- "${BASH_SOURCE[0]}")/support/project-root.sh"
source "$(dirname -- "${BASH_SOURCE[0]}")/support/exit-codes.sh"
source "$(dirname -- "${BASH_SOURCE[0]}")/support/quality-runs.sh"

# Pint ignores dot-files and dot-directories by default. Projects using this
# gate also reserve .ai, .github and .claude for tooling and omit them from
# Rector's paths. File mode skips them so a direct invocation cannot bypass
# that project-wide scope.
is_hidden_path() {
    local relative_path="$1" segment
    local IFS='/'
    for segment in $relative_path; do
        [[ "$segment" == .* ]] && return 0
    done
    return 1
}

# A direct Pint invocation bypasses the `exclude` and `notPath` lists in
# pint.json. File mode applies that denylist before passing an explicit path.
# Returns success when the path should be checked or no denylist exists.
pint_covers_path() {
    local relative_path="$1"
    [[ -f pint.json ]] || return 0
    command -v jq >/dev/null 2>&1 || return 0

    local excluded_paths
    excluded_paths="$(jq -r '(.exclude // []) + (.notPath // []) | .[]' pint.json 2>/dev/null)"
    [[ -n "$excluded_paths" ]] || return 0

    local excluded_path
    while IFS= read -r excluded_path; do
        case "$relative_path" in
            "$excluded_path" | "$excluded_path"/* | */"$excluded_path" | */"$excluded_path"/*) return 1 ;;
        esac
    done <<< "$excluded_paths"

    return 0
}

# Every PHP file with an uncommitted change (staged, unstaged or new), the same
# set Pint's --dirty checks, so Rector, which has no --dirty flag, can be scoped
# to it. Hidden paths are dropped, see is_hidden_path. --relative makes paths
# relative to $root, the current directory here; git's default, the repository
# toplevel, is wrong for a project nested below the Git root.
dirty_php_files() {
    local file
    { git diff --name-only --relative --diff-filter=ACMR HEAD -- . 2>/dev/null
      git ls-files --others --exclude-standard -- . 2>/dev/null
    } | grep '\.php$' | sort -u | while IFS= read -r file; do
        is_hidden_path "$file" || printf '%s\n' "$file"
    done
}

run_rector_dirty() {
    local files=() file
    while IFS= read -r file; do
        [[ -n "$file" ]] && files+=("$file")
    done < <(dirty_php_files)
    (( ${#files[@]} == 0 )) && return 0
    vendor/bin/rector process "${files[@]}" --dry-run --no-progress-bar --memory-limit="$memory_limit"
}

# With vendor/bin/paratest installed, the suite runs in parallel. Pest and
# `artisan test` take --parallel; plain PHPUnit has no such flag, so paratest
# replaces vendor/bin/phpunit.
run_test_suite() {
    local parallel=""
    $has_paratest && parallel="--parallel"

    if $has_pest; then
        php -d memory_limit="$memory_limit" vendor/bin/pest ${parallel:+"$parallel"}
    elif $has_phpunit && $has_paratest; then
        php -d memory_limit="$memory_limit" vendor/bin/paratest
    elif $has_phpunit; then
        php -d memory_limit="$memory_limit" vendor/bin/phpunit
    elif $has_artisan; then
        php -d memory_limit="$memory_limit" artisan test ${parallel:+"$parallel"}
    fi
}

mode="${1:-}"
file="${2:-}"

case "$mode" in
    file|fast|full) ;;
    *)
        echo "Usage: quality-gate.sh <file|fast|full> [path]" >&2
        exit "$exit_usage"
        ;;
esac

canonical=""

if [[ "$mode" == "file" ]]; then
    if [[ -z "$file" ]]; then
        echo "The file mode requires a path." >&2
        exit "$exit_usage"
    fi
    if [[ ! -f "$file" ]]; then
        echo "Not a regular file: $file" >&2
        exit "$exit_usage"
    fi

    canonical="$(
        cd "$(dirname -- "$file")" >/dev/null 2>&1 &&
        printf '%s/%s' "$(pwd -P)" "$(basename -- "$file")"
    )" || exit "$exit_usage"

    # A repository can nest several Composer projects, so the file's own
    # directory decides which one is gated, not the shell's current directory.
    start_dir="$(dirname -- "$canonical")"
else
    start_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
fi

resolve_project_root "$start_dir" git_root root || {
    echo "QUALITY_NO_PROJECT: no Composer project (composer.json) found for $start_dir" >&2
    exit "$exit_nothing_to_check"
}

if [[ "$mode" == "file" ]]; then
    if [[ "$canonical" != *.php ]] && [[ "$(basename -- "$canonical")" != "composer.json" ]]; then
        exit 0
    fi
fi

cd "$root" || exit "$exit_internal"

# vendor/bin/* shebangs and the php calls below find `php` on PATH, never the
# interactive `php='herd php'` alias. A project isolated to another Herd PHP
# version would run every check with the wrong interpreter, so the binary
# `herd which-php` names is linked into a directory ahead of PATH. This runs
# after the cd because Herd answers for the site in the current directory, and
# does nothing without Herd, as on CI.
#
# Hooks run non-interactively, where .zshrc has not put Herd on PATH, so its
# default install location is the fallback.
herd_bin="$(command -v herd || true)"
if [[ -z "$herd_bin" && -x "$HOME/Library/Application Support/Herd/bin/herd" ]]; then
    herd_bin="$HOME/Library/Application Support/Herd/bin/herd"
fi
php_bin="$([[ -n "$herd_bin" ]] && "$herd_bin" which-php 2>/dev/null)"
if [[ -x "$php_bin" ]]; then
    php_shim_dir="$(mktemp -d)"
    trap 'rm -rf "$php_shim_dir"' EXIT
    ln -s "$php_bin" "$php_shim_dir/php"
    PATH="$php_shim_dir:$PATH"
fi

has_pint=false;     [[ -x vendor/bin/pint    ]] && has_pint=true
has_phpstan=false;  [[ -x vendor/bin/phpstan ]] && has_phpstan=true
has_rector=false;   [[ -x vendor/bin/rector  ]] && has_rector=true
has_pest=false;     [[ -x vendor/bin/pest    ]] && has_pest=true
has_phpunit=false;  [[ -x vendor/bin/phpunit ]] && has_phpunit=true
has_artisan=false;  [[ -f artisan            ]] && has_artisan=true
has_composer=false; command -v composer >/dev/null 2>&1 && has_composer=true
has_paratest=false; [[ -x vendor/bin/paratest ]] && has_paratest=true

if ! $has_pint && ! $has_phpstan && ! $has_rector && ! $has_pest && ! $has_phpunit && ! $has_artisan && ! $has_composer; then
    echo "QUALITY_NO_TOOLING: no Pint, PHPStan, Rector, Pest, PHPUnit, Artisan or composer found in $root" >&2
    # Without tooling there is nothing left to prove clean, so fast and full
    # clear the dirty marker here, as they would after a passing run.
    [[ "$mode" != "file" ]] && rm -f "$quality_runs_dir$root.dirty"
    exit "$exit_nothing_to_check"
fi

status=0

# PHP's default 128M is too little for PHPStan or a test run, and PHP does not
# read PHP_MEMORY_LIMIT on its own, so the limit is passed explicitly to
# PHPStan, Rector and the PHP test runners.
memory_limit="${PHP_MEMORY_LIMIT:-2G}"

case "$mode" in
    file)
        relative="${canonical#"$root"/}"
        if [[ "$(basename -- "$canonical")" == "composer.json" ]]; then
            $has_composer && { composer validate --no-check-all --strict || status=$?; }
        elif is_hidden_path "$relative"; then
            : # See is_hidden_path.
        else
            if $has_pint && pint_covers_path "$relative"; then
                vendor/bin/pint --test "$canonical" || status=$?
            fi
            if $has_rector && [[ -z "${CLAUDE_QUALITY_SKIP_RECTOR:-}" ]]; then
                vendor/bin/rector process "$canonical" --dry-run --no-progress-bar --memory-limit="$memory_limit" || status=$?
            fi
        fi
        ;;
    fast)
        $has_pint     && { vendor/bin/pint --dirty --test || status=$?; }
        $has_rector   && [[ -z "${CLAUDE_QUALITY_SKIP_RECTOR:-}" ]] && { run_rector_dirty || status=$?; }
        $has_phpstan  && { vendor/bin/phpstan analyse --no-progress --memory-limit="$memory_limit" || status=$?; }
        $has_composer && { composer validate --no-check-all --strict || status=$?; }
        [[ -z "${CLAUDE_QUALITY_SKIP_TESTS:-}" ]] && { run_test_suite || status=$?; }
        ;;
    full)
        $has_pint     && { vendor/bin/pint --test || status=$?; }
        $has_phpstan  && { vendor/bin/phpstan analyse --no-progress --memory-limit="$memory_limit" || status=$?; }
        $has_rector   && { vendor/bin/rector process --dry-run --no-progress-bar --memory-limit="$memory_limit" || status=$?; }
        $has_composer && { composer validate --no-check-all --strict || status=$?; }
        $has_composer && { composer audit || status=$?; }
        run_test_suite || status=$?
        ;;
esac

if [[ "$mode" != "file" ]]; then
    record="$quality_runs_dir$root.json"
    marker="$quality_runs_dir$root.dirty"
    mkdir -p "$(dirname -- "$record")"

    sha="$(git rev-parse --short HEAD 2>/dev/null || echo none)"
    tree="clean"
    [[ -n "$(git status --porcelain 2>/dev/null)" ]] && tree="dirty"
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    printf '{"root":"%s","mode":"%s","sha":"%s","tree":"%s","exit":%d,"started":"%s"}\n' \
        "$root" "$mode" "$sha" "$tree" "$status" "$now" > "$record"

    (( status == 0 )) && rm -f "$marker"
fi

exit "$status"
