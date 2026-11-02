#!/usr/bin/env bash
# Lists the hits a characterization run can find mechanically in its own uncommitted changes, staged or
# not: files it must not touch, changed production packages, tests made easier, checks silenced, coverage
# exclusions, changed snapshots. Each hit needs a look: fix it or explain it in the report. Exits 1 when
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

report "Production packages changed in composer.lock" \
    "$(changed_production_packages)"

report "Tests made easier or focused" \
    "$(added_test_lines | grep -E -- '(\}\)|\)\)|^\+([^:]+: )?[[:space:]]*)->(skip|todo|only)\(|markTestSkipped|markTestIncomplete|TODO' || true)"

report "Checks silenced" \
    "$(added_test_lines | grep -E '@codeCoverageIgnore|@pest-mutate-ignore|@phpstan-ignore|phpcs:ignore' || true)"

report "Deleted test files" \
    "$(git diff HEAD --name-only --diff-filter=D -- tests)"

report "Assertions removed from existing tests (check each: moved or gone?)" \
    "$(git diff HEAD --unified=0 -- tests ':!tests/.pest' | grep '^-' | grep -v '^---' | grep -E 'assert|expect\(|->to[A-Z]' || true)"

report "Snapshots changed after they were committed" \
    "$(git diff HEAD --name-only -- tests/.pest/snapshots)"

report "Coverage exclusions and thresholds changed (each needs its reason in the report)" \
    "$(git diff HEAD --unified=0 -- phpunit.xml composer.json | grep -E '^[-+].*(<file>|<directory>|<exclude>|--min|--exactly|--coverage)' || true)"

if [[ $hits -eq 0 ]]; then
    echo "No hits."
fi

exit "$hits"
