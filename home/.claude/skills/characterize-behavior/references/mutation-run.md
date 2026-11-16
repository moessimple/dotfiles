# Mutation run

Coverage shows which lines ran, not whether a test checks what they do. Run it once per area, after its coverage gaps are closed, on the area's classes only:

```bash
XDEBUG_MODE=coverage vendor/bin/pest --mutate --covered-only --parallel --class={the area's classes or namespaces, comma-separated}
```

Never add `--everything`: it overrides `--class` and mutates the whole project.

Where the installed Pest version documents an option that selects files by path, it may take the area's paths instead of `--class`.

Pest mutates only PHP files under `<source>`. Blade views, routes, configuration, and migrations are never mutated, so explicit assertions are their only net; the report says so.

## Which survivors lead to a test

The goal is that every behaviour an actor can observe is pinned, not a score: mutants are highly redundant, and killing every one produces tests that exist only for the metric. For each survivor, ask whether the change alters something a user, an API client, the scheduler, the queue, or an operator can observe.

- **Yes, and no test pins it:** add the test that observes it at the entry point, under the check in [test-style.md](test-style.md), Keeping a new test.
- **Only a test of an implementation detail would catch it** (an internal cache key, which model event fires, a constant no actor sees): do not write it; record the mutation with that reason.
- **No actor can observe it** (for example a default every caller overrides, naming those callers): record it as equivalent with the reason. Check that no entry point exposes it before calling it equivalent.

Record each one under Equivalent mutations in `tests/CHARACTERIZATION.md`. Record the area's score in the area table. Those in high-risk capabilities stay `Confirmed: open` for a person to confirm. raise-quality-gate takes this list as its baseline.

## Pitfalls

- **All mutations of a covered file untested:** Pest swaps in a mutated file only after boot, so a class that `tests/Pest.php` or the test case file loads earlier (such as a fixture model declared next to the test case) runs unmutated. Move such fixtures into their own files under `autoload-dev`.
- **Forked processes** (`pcntl_fork`) record no coverage, so their tests never run against a mutant. Pin the observable outcome in-process where possible; otherwise record the mutant as caught only by the forked test.

## After the characterization

Later changes check only the classes they touch: `--mutate --class={changed classes} --covered-only`, which is what a planned change does before the change is made. Mutating only changed code keeps mutation testing affordable.
