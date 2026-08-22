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
# No gate-specific project file is required. The script detects installed
# Laravel/PHP tools and uses each project's own tool configuration. It executes
# only installed vendor binaries or `artisan`, the trust boundary already
# crossed by `composer install`. The global Composer binary handles validation
# in every applicable mode and auditing in full mode.
#
# support/project-root.sh requires composer.json at the Git toplevel.

set -u

# A `vendor/bin/*` binary resolves `php` via its own shebang, and the php
# invocations below call it directly. Both only see PATH, never the
# interactive `php='herd php'` shell alias, so a project isolated to a
# non-global Herd PHP version would otherwise run every check here against
# the wrong interpreter. Resolved once via Herd's own `which-php` and
# exposed as a plain symlink ahead of PATH, so every invocation below stays
# unchanged and still resolves the right interpreter through it. No-op when
# Herd is not installed (CI runs this suite on Ubuntu, without Herd).
php_bin="$(command -v herd >/dev/null 2>&1 && herd which-php 2>/dev/null)"
if [[ -x "$php_bin" ]]; then
    php_shim_dir="$(mktemp -d)"
    ln -s "$php_bin" "$php_shim_dir/php"
    PATH="$php_shim_dir:$PATH"
fi

source "$(dirname -- "${BASH_SOURCE[0]}")/support/project-root.sh"

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

# Mirrors Pint's own --dirty semantics (every PHP file with an uncommitted
# change: staged, unstaged, or new) so Rector, which has no --dirty flag of
# its own, can be scoped to the same bounded set of files in fast mode.
# --relative forces paths relative to the caller's cwd (already $root by the
# time this runs), matching what a relative `vendor/bin/rector process <path>`
# call expects.
dirty_php_files() {
    { git diff --name-only --relative --diff-filter=ACMR HEAD -- . 2>/dev/null
      git ls-files --others --exclude-standard -- . 2>/dev/null
    } | grep '\.php$' | sort -u
}

# Rector has no --dirty flag of its own; this gives it Pint's scope instead
# of the whole project.
run_rector_dirty() {
    local files=()
    while IFS= read -r file; do
        [[ -n "$file" ]] && files+=("$file")
    done < <(dirty_php_files)
    (( ${#files[@]} == 0 )) && return 0
    vendor/bin/rector process "${files[@]}" --dry-run --no-progress-bar --memory-limit="$memory_limit"
}

# full always calls this; fast only when CLAUDE_QUALITY_SKIP_TESTS is unset.
# vendor/bin/paratest, when installed, runs the suite in parallel: Pest and
# `artisan test` both take --parallel directly, but plain PHPUnit has no such
# flag of its own, so paratest replaces vendor/bin/phpunit outright instead.
run_test_suite() {
    if $has_pest; then
        if $has_paratest; then
            php -d memory_limit="$memory_limit" vendor/bin/pest --parallel
        else
            php -d memory_limit="$memory_limit" vendor/bin/pest
        fi
    elif $has_phpunit; then
        if $has_paratest; then
            php -d memory_limit="$memory_limit" vendor/bin/paratest
        else
            php -d memory_limit="$memory_limit" vendor/bin/phpunit
        fi
    elif $has_artisan; then
        if $has_paratest; then
            php -d memory_limit="$memory_limit" artisan test --parallel
        else
            php -d memory_limit="$memory_limit" artisan test
        fi
    fi
}

exit_nothing_to_check=3
exit_usage=64
exit_unsafe_path=65
exit_internal=66

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
    )" || exit "$exit_unsafe_path"

    # Resolve from the file itself so `quality file <path>` checks the
    # repository that owns the path even when invoked from elsewhere.
    start_dir="$(dirname -- "$canonical")"
else
    start_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
fi

resolve_project_root "$start_dir" root || {
    echo "QUALITY_NO_PROJECT: no composer.json found at the Git repository root for $start_dir" >&2
    exit "$exit_nothing_to_check"
}

if [[ "$mode" == "file" ]]; then
    # .git is checked before the general containment check, because a path
    # inside .git would otherwise pass as "inside the project".
    case "$canonical" in
        "$root"/.git/*)
            echo "Refusing a path inside .git: $canonical" >&2
            exit "$exit_unsafe_path"
            ;;
        "$root"/*) ;;
        *)
            echo "Path is outside the project: $canonical" >&2
            exit "$exit_unsafe_path"
            ;;
    esac

    # Nothing to check for anything but a PHP file or composer.json; exit
    # before touching any tool.
    if [[ "$canonical" != *.php ]] && [[ "$(basename -- "$canonical")" != "composer.json" ]]; then
        exit 0
    fi

    # Only the repository-level manifest belongs to this project.
    if [[ "$(basename -- "$canonical")" == "composer.json" && "$canonical" != "$root/composer.json" ]]; then
        exit 0
    fi
fi

cd "$root" || exit "$exit_internal"

config_home="${XDG_CONFIG_HOME:-$HOME/.config}/claude-quality"

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
    # A root with no tooling has nothing left to prove clean, so its dirty
    # marker must not stay stuck forever.
    # Fast and full normally clear that marker after a successful run, so a
    # stale one is cleared here too.
    [[ "$mode" != "file" ]] && rm -f "$config_home/runs$root.dirty"
    exit "$exit_nothing_to_check"
fi

status=0

# PHP's default 128M is too little for PHPStan or a test run, and PHP does not
# read PHP_MEMORY_LIMIT on its own, so the limit is passed explicitly to
# PHPStan, Rector and the PHP test runners.
memory_limit="${PHP_MEMORY_LIMIT:-8192M}"

case "$mode" in
    file)
        relative="${canonical#"$root"/}"
        if [[ "$(basename -- "$canonical")" == "composer.json" ]]; then
            $has_composer && { composer validate --no-check-all --strict || status=$?; }
        elif is_hidden_path "$relative"; then
            : # Neither tool's own project-wide run would reach a dot-file or a
              # file under a dot-directory, see is_hidden_path above.
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
    record="$config_home/runs$root.json"
    marker="$config_home/runs$root.dirty"
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
