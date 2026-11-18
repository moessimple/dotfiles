#!/usr/bin/env bash
# Lists the hits a characterization run can find mechanically in its own uncommitted changes, staged or
# not: files it must not touch, changed or deleted acceptance tests, a changed acceptance guard or lock
# entry, acceptance tests missing from the lock, changed production packages, tests made easier, checks
# silenced, coverage exclusions. Each hit needs a look: fix it or explain it in the report. Exits 1 when
# there is any hit; a run that made the coverage gate the test command always has that one. Run it from
# the project root.

set -euo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Run this inside the project's git repository." >&2
    exit 1
fi

hits=0

# Prints a heading and the given lines when there are any, and counts them as a hit.
report() {
    local heading=$1 lines=$2

    if [[ -n $lines ]]; then
        printf '\n## %s\n\n%s\n' "$heading" "$lines"
        hits=1
    fi
}

# Added lines in tracked test files, and every line of untracked ones.
added_test_lines() {
    git diff HEAD --unified=0 -- tests phpunit.xml | grep '^+' | grep -v '^+++' || true
    git ls-files --others --exclude-standard -- tests | grep '\.php$' | while read -r file; do
        sed "s|^|+${file}: |" "$file"
    done
}

# Committed test files holding acceptance tests (Pest group "acceptance") that are changed, renamed, or
# deleted. The committed version decides, so removing the group from a file is a hit too. grep reads the
# whole file instead of quitting early (-q), so pipefail never sees git show die of SIGPIPE.
changed_acceptance_tests() {
    git diff HEAD --name-status --diff-filter=DMR -- tests | while IFS=$'\t' read -r status file _; do
        if git show "HEAD:$file" 2>/dev/null | grep -E "group\(['\"]acceptance['\"]\)" >/dev/null; then
            printf '%s\t%s\n' "$status" "$file"
        fi
    done
}

# The "path": "hash" entries of an acceptance lock file read from stdin, one per line, without the
# separating comma, so adding an entry after the last one does not change the lines before it.
lock_entries() {
    grep -oE '"[^"]+"[[:space:]]*:[[:space:]]*"[0-9a-f]{64}"' | sed -E 's/[[:space:]]*:[[:space:]]*/: /' || true
}

# A changed or deleted committed acceptance guard test, and every entry of HEAD's
# tests/acceptance.lock.json that is changed or gone. New entries are expected and not listed.
changed_acceptance_guard() {
    git diff HEAD --name-status -- tests/Unit/AcceptanceGuardTest.php

    if ! git cat-file -e HEAD:tests/acceptance.lock.json 2>/dev/null; then
        return
    fi

    local current=""
    if [[ -f tests/acceptance.lock.json ]]; then
        current=$(lock_entries <tests/acceptance.lock.json)
    fi

    git show HEAD:tests/acceptance.lock.json | lock_entries | while read -r entry; do
        if ! grep -qxF -- "$entry" <<<"$current"; then
            printf 'tests/acceptance.lock.json: %s\n' "$entry"
        fi
    done
}

# Test files holding acceptance tests, tracked or new, whose path is no key in tests/acceptance.lock.json,
# so the guard test would not notice a later edit. Every one is a hit while the lock is missing.
unlocked_acceptance_tests() {
    local keys=""
    if [[ -f tests/acceptance.lock.json ]]; then
        keys=$(lock_entries <tests/acceptance.lock.json | sed -E 's/^"([^"]+)": .*/\1/')
    fi

    {
        git ls-files -- tests
        git ls-files --others --exclude-standard -- tests
    } | { grep '\.php$' || true; } | while read -r file; do
        if grep -E "group\(['\"]acceptance['\"]\)" "$file" >/dev/null 2>&1 && ! grep -qxF -- "$file" <<<"$keys"; then
            printf '%s\n' "$file"
        fi
    done
}

# Production packages whose locked version or commit differs from HEAD's composer.lock.
changed_production_packages() {
    if [[ ! -f composer.lock ]] || ! git cat-file -e HEAD:composer.lock 2>/dev/null; then
        return
    fi

    git show HEAD:composer.lock | php -r '
        $locked = function (string $json): array {
            $packages = [];
            foreach (json_decode($json, true)["packages"] ?? [] as $package) {
                $packages[$package["name"]] = $package["version"] . " " . ($package["source"]["reference"] ?? $package["dist"]["reference"] ?? "");
            }
            return $packages;
        };
        $before = $locked(stream_get_contents(STDIN));
        $after = $locked(file_get_contents("composer.lock"));
        foreach (array_unique([...array_keys($before), ...array_keys($after)]) as $name) {
            if (($before[$name] ?? null) !== ($after[$name] ?? null)) {
                printf("- %s: %s -> %s\n", $name, $before[$name] ?? "none", $after[$name] ?? "none");
            }
        }
    '
}

report "Changed files the skill must not touch" \
    "$(git status --porcelain -- app src routes config resources bootstrap database/migrations database/seeders public docs .env .env.example ':(glob)*.md')"

report "Acceptance tests changed or deleted (only an explicit request for that rule allows it)" \
    "$(changed_acceptance_tests)"

report "Acceptance guard or lock entries changed (only an explicit request for that rule allows it)" \
    "$(changed_acceptance_guard)"

report "Acceptance tests missing from tests/acceptance.lock.json (add each with its SHA-256)" \
    "$(unlocked_acceptance_tests)"

report "Production packages changed in composer.lock" \
    "$(changed_production_packages)"

report "Tests made easier or focused" \
    "$(added_test_lines | grep -E -- '(\}\)|\)\)|^\+([^:]+: )?[[:space:]]*)->(skip|todo|only)\(|markTestSkipped|markTestIncomplete|TODO' || true)"

report "Checks silenced" \
    "$(added_test_lines | grep -E '@codeCoverageIgnore|@pest-mutate-ignore|@phpstan-ignore|phpcs:ignore' || true)"

report "Deleted test files" \
    "$(git diff HEAD --name-only --diff-filter=D -- tests)"

report "Assertions removed from existing tests (check each: moved or gone?)" \
    "$(git diff HEAD --unified=0 -- tests | grep '^-' | grep -v '^---' | grep -E 'assert|expect\(|->to[A-Z]' || true)"

report "Coverage exclusions and thresholds changed (each needs its reason in the report)" \
    "$(git diff HEAD --unified=0 -- phpunit.xml composer.json | grep -E '^[-+].*(<file>|<directory>|<exclude>|--min|--exactly|--coverage)' || true)"

if [[ $hits -eq 0 ]]; then
    echo "No hits."
fi

exit "$hits"
