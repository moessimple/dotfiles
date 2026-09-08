---
name: sync-skeleton
description: Pull the quality gate and tooling config from a Laravel starter kit into a project bootstrapped from it. Use to sync a project with its starter kit, pull the quality gate, or run a skeleton sync. Compares project-now against kit-now, groups every file by purpose, and applies one commit per bucket on a dedicated branch. Never touches app code, migrations, routes, or bootstrap.
---

# Sync Skeleton

Bring quality-gate and tooling progress from `moessimple/laravel-starter-kit`
into a project that was bootstrapped from it, without hand-diffing and without
risk to app code.

- The project's git history is unrelated to the kit's. There is no common
  ancestor. Compare project-now against `origin/<default-branch>`-now, byte by
  byte.
- The kit is treated as a near-static target state, not a stream of features.
- Sync runs one way only: kit into project.
- Every file is classified and grouped into a bucket. The user selects buckets;
  each selected bucket becomes one commit on a dedicated branch.
- **P1 quality-gate and P2 frontend-tooling are kit-authoritative.** The kit's
  value is exactly this configuration (`README#why-this-starter-kit`,
  `README#available-tooling`), so for these two buckets the kit wins every
  `differs`, `deleted-upstream` tooling files are removed, and the dependency
  sets are converged onto the kit's. The user can veto a specific file or
  dependency, and each veto is recorded as a deliberate deviation. P3-P8 stay
  conservative (keep the project's copy on doubt).
- The goal is a project whose gate *configuration* matches the kit's, verified
  file by file in Phase 7. A *green* gate is not guaranteed: PHPStan level max,
  100% coverage, and strict types land on app code this skill never edits. It
  applies the config and hands the user the `composer test` output as the
  to-do list.
- App code, migrations, routes, `bootstrap/**`, and project config outside the
  gate are never-touch.

Invocation: `/sync-skeleton [target]`. `target` defaults to the git toplevel of
the current directory.

## Safety contract (read to the user before any side effect)

1. The working tree must be clean. If `git status --porcelain` is non-empty,
   stop and tell the user to commit or stash. Never stash for them.
2. All work happens on `sync-skeleton/<yyyymmdd-hhmm>-<slug>`. The user's current
   branch is never modified.
3. One bucket is one commit. The message names the kit SHA and, per file, the
   decision (added / took-upstream / manual-merge / kept).
4. Conflict handling depends on the bucket. P1 quality-gate and P2
   frontend-tooling: the kit version wins by default; show the diff, apply the
   kit's copy, and let the user veto per file (a veto is recorded, not silent).
   P3-P8: never auto-resolve; if the user is unsure, keep their copy and move on.
5. Never overwrite a manifest or lockfile wholesale. `composer.json` /
   `package.json` change only through the `plan-manifest.sh` directives
   (`add` / `align` / `remove` on `require-dev` / `devDependencies`) and the
   `scripts` realignment, then regenerate the lockfile.
6. Behavior guarantee: run `composer test` (or a reduced subset) before the run
   and again after the last bucket. Compare. See Phase 7 for how P1/P2/P3 change
   the reading.
7. On ambiguous signals, ask. Do not guess.

If any of these cannot hold, abort with a clear message about what went wrong
and how to recover.

## Required tools

- `git` in the project. Required.
- `gh` optional, only to enrich commit titles. Fall back to `git log`.
- `bash` for the bundled scripts. No `jq`.

## Scripts

All under `scripts/`. Every script takes the profile as its first argument
(default and only value: `laravel-starter-kit`).

- `preflight.sh [profile] [target]` - git repo, clean tree, looks like a
  descendant of this skeleton. Exit 1 not-a-repo, 2 dirty (writes
  `git status --short` to stderr), 3 not-a-descendant, 64 bad args. Prints
  `preflight: OK` on success.
- `fetch-kit.sh [profile]` - reuse `~/Code/laravel-starter-kit` when its origin
  is the kit (fetch only, never checkout or reset), otherwise blobless-clone
  into a temp dir. Prints one line: `<kit_dir>\t<default-branch>\t<sha>`.
- `classify.sh <profile> <kit_dir> <default-branch> <target>` - one line per
  path, `<status>\t<bucket>\t<path>`. Status is
  `new | identical | differs | differs-binary | deleted-upstream | manifest`.
  Bucket is one of the catalog buckets, `never-touch`, `drift-only`,
  `not-in-scope`, or `unclassified` (matched no cascade arm; the kit added a file
  the map does not know yet). Comparison is `cmp -s` against
  `git show origin/<branch>:<path>`.
- `plan-manifest.sh <profile> <kit_dir> <default-branch> <target>` - one
  directive per line, `<add|align|remove>\t<php|npm>\t<name>\t<constraint>`,
  that converges the project's `require-dev` / `devDependencies` onto the kit's:
  `add` (kit has it, project lacks it), `align` (both, different constraint,
  value is the kit's), `remove` (project carries an eslint/prettier-family
  package the kit dropped for vite-plus). Runtime `require` / `dependencies` are
  never inspected. Phase 6 applies the directives; Phase 7 re-runs it and expects
  no output.

Read `reference/profiles/laravel-starter-kit.md` before presenting the catalog.
It is the human copy of the bucket map; the machine truth is the cascade in
`classify.sh`, and `tests/claude/skills/sync-skeleton/buckets.bats` keeps them in
step.

## Workflow

Seven phases, in order. Each establishes what the next relies on.

### Phase 1: Choose and confirm the profile

Determine the profile from project markers (`composer.json` type, structure).
Today there is exactly one, `laravel-starter-kit`, so this is trivial. State it
out loud. Run:

```
scripts/preflight.sh laravel-starter-kit <target>
```

Surface its message verbatim and stop on any non-zero exit.

Then check the environment against what the kit's README requires and record it
for the report: PHP `>= 8.5` (`php -v`), Node `>= 24` (`node -v` vs `.nvmrc`),
and a coverage driver (Xdebug or PCOV, `php -m`). A mismatch is not a stop, but
it means `composer update` may refuse to resolve and the 100% coverage gate
cannot run locally; note it and carry on.

### Phase 2: Fetch the kit and classify

```
kit_line=$(scripts/fetch-kit.sh laravel-starter-kit)
# kit_line is: <kit_dir>\t<default-branch>\t<sha>
scripts/classify.sh laravel-starter-kit <kit_dir> <default-branch> <target>
```

Hold onto the kit SHA for the commit messages and the report.

### Phase 3: Show the catalog and drift report, get the selection

Present buckets in priority order (P1 first). For each bucket list its files
grouped by status.

- **P1 quality-gate** and **P2 frontend-tooling** preselect `new` *and*
  `differs`, and are **kit-authoritative**: the plan is to take the kit's copy
  of every `differs` file, delete every `deleted-upstream` tooling file, and
  apply every `plan-manifest.sh` directive. Present this as one list ("these
  files become the kit's version; veto any") rather than a yes/no per file. A
  veto is allowed and is written into the report as a deliberate deviation with
  the user's reason.
- **P3 essentials** through **P8 misc-config** preselect only `new`.
- If `plan-manifest.sh` emits any `remove npm eslint*/prettier*` directive, the
  project still runs eslint/prettier while the kit has moved to vite-plus. Flag
  the **toolchain migration** (Phase 6) as part of P2 so the user opts in with
  eyes open: it is a toolchain swap, not a config bump.
- `never-touch` `differs` stays silent. `never-touch` `new` appears only under a
  short "other new files" note.
- `not-in-scope` paths never appear.
- `unclassified` paths always appear, in their own "kit added something the map
  does not know - place by hand" block. Never preselected, never auto-applied.
  Before finishing the run, add a cascade arm and a profile line for each, so the
  next run classifies it properly.

**Drift report** (per `differs` file in a bucket): path, bucket, changed line
count, and a rating:

- `< 10` changed lines: "probably trivial drift"
- `>= 10`: "larger divergence, review deliberately"
- binary: "binary file differs"

`never-touch` `differs` only under `--verbose`. `identical` never.

**Guided manifest diffs** as their own block. Run `plan-manifest.sh` and show its
`add` / `align` / `remove` directives for `require-dev` and `devDependencies`,
plus the `scripts` diff for both manifests against `git show
origin/<branch>:composer.json` / `:package.json`. Each directive is applied in
Phase 6 unless vetoed. `align` may move a constraint *backwards* to the kit's
floor; call that out so the user can veto if the project needs the newer
version. Runtime `require` / `dependencies` are shown, never written.

**Drift-only block** (show the diff, never write, never preselect): `.gitignore`,
`.env.example`, `CLAUDE.md`.

**Manual app-code follow-ups** as their own block, never applied. When
`quality-gate` / `frontend-tooling` / `essentials` is selected, list the
app-code parts of the kit's strict-quality-gate change with the kit diff as
reference:

- `app/Providers/AppServiceProvider.php` - `configureDefaults()` may fall away
  because Essentials takes over immutable dates, the destructive-command guard,
  and default password rules. Check for collisions.
- `routes/web.php` - the kit replaces the `Route::inertia()` macro with an
  explicit closure (larastan resolves the macro as `mixed`). Project-specific.
- `app/Models/User.php`, `database/factories/UserFactory.php` - strict types, a
  `casts()` method instead of `$casts`.
- Missing `declare(strict_types=1)` in app files turns the arch test
  `strict types everywhere` red.
- `tests/Pest.php` (never-touch) needs the wiring the applied arch/browser tests
  rely on: `freezeDeterministicState()` in `beforeEach`,
  `->in('Arch', 'Unit', 'Http', 'Console')`, `LazilyRefreshDatabase` on Http and
  Console, and `require_once __DIR__.'/Browser/Pest.php'`. Until then the arch
  suite errors on load.
- `tests/Http/WelcomeTest.php` (applied as `new` in P4) calls `route('home')`
  and asserts an Inertia `Welcome` component; `config/inertia.php` has
  `ensure_pages_exist`. A descendant that renamed the home route or page must
  adjust the test or skip it.
- Browser suite: `composer test:browser` needs `tests/Browser/Pest.php` (applied
  in P4 only when absent) plus a one-time `npx playwright install chromium`
  (the kit does this in `composer setup`, which is not synced).
- Files the kit deleted: `resources/js/lib/utils.ts` is removed by the P2
  kit-authoritative arm (its `cn(` / `@/lib/utils` callers become app-code
  follow-ups). `tests/Feature/ExampleTest.php`, `tests/Unit/ExampleTest.php` are
  P4, still remove-only-on-request.
- Environment: PHP 8.5, Node 24. `roave/security-advisories` (dev-latest) will
  block a future `composer update` once a dependency has an advisory.

Wait for the selection. Echo it back. Confirm once more before any side effect.

### Phase 4: Baseline and workspace

Record the before-state so Phase 7 can tell a regression from a pre-existing
failure:

```
composer test        # or, for a slow suite: composer test:lint && composer test:types
```

Note in the report if the reduced subset was used. Then create the branch:

```
git -C <target> switch -c "sync-skeleton/$(date +%Y%m%d-%H%M)-<first-bucket-slug>"
```

If the user is already on a `sync-skeleton/...` branch from an earlier run, do
not delete it. Ask whether to resume on it, start fresh, or abort.

From here every write goes to this branch.

### Phase 5: Apply each selected bucket

For each bucket, in priority order:

1. Write every `new` file from `git show origin/<branch>:<path>` and stage it.
   Before writing, check the rename gotcha: if a `new` path's basename already
   exists elsewhere in the project, surface it, do not auto-apply.
2. Scan the applied `new` files for imports of helpers outside this bucket
   (`@/`, `~/`, `./`, `../`). Report any missing target as a follow-up
   dependency; do not book the bucket as done.
3. Walk `differs`, `differs-binary`, and `deleted-upstream`. Always show the kit
   version (`git show origin/<branch>:<path>`), the project version, and the diff
   (`/usr/bin/diff -u` or `git --no-pager diff --no-index`, never the `diff`
   alias). Then, by bucket:
   - **P1 quality-gate, P2 frontend-tooling (kit-authoritative):** write the kit
     version for every `differs` / `differs-binary`; delete every
     `deleted-upstream` file (`eslint.config.*`, `.prettierrc*`,
     `.prettierignore`, `resources/js/lib/utils.ts`). Stage it. The user may veto
     a specific file; record the veto and its reason for the report and Phase 7.
   - **P3-P8:** the user picks per file: take the kit version wholesale (lossy,
     confirm separately), keep theirs, or merge by hand. Unsure twice: keep
     theirs, move on. `deleted-upstream` here: keep by default.
   - `.ai/rules/actions.md` and `.ai/rules/index.md`: always `differs`, never an
     auto proposal, even in P6, even though P6 is otherwise conservative.
4. Commit the bucket:

```
git -C <target> commit -m "sync-skeleton: <bucket>

Upstream: moessimple/laravel-starter-kit@<sha>
Added: <list>
Took upstream: <list>
Manual merge: <list>
Kept: <list>"
```

### Phase 6: Reconcile manifests

If a selected bucket touched `composer.json` or `package.json`, apply the guided
partial diffs the user approved. Script aliases, then dependency directives, then
the toolchain migration when it is triggered:

1. **Adopt the kit's script aliases, do not just check equivalents exist.**
   Bring in every kit `scripts` entry for the quality gate (`dev`, `lint`,
   `test:lint`, `test:types`, `test:type-coverage`, `test:unit`, `test:browser`,
   `test`, `update:dependencies` in `composer.json`; `build`, `dev`, `lint`,
   `test:lint`, `test:unit`, `test:types` in `package.json`). Where the project
   has diverged, align the alias body to the kit's exact commands and order.
   Keep only steps the project genuinely adds for paths the kit does not have
   (e.g. a monorepo sub-package fan-out), appended after the kit's commands.
   A project alias that merely wraps the same tool differently
   (`vendor/bin/pest` vs `pest`, an added `--memory-limit`, a reordered chain)
   is realigned to the kit; flag any such change so the user can veto it.
2. **Dependency sets: apply every `plan-manifest.sh` directive.**

   ```
   scripts/plan-manifest.sh laravel-starter-kit <kit_dir> <default-branch> <target>
   ```

   - `add` / `align`: write the kit's constraint into `require-dev` /
     `devDependencies`.
   - `remove`: delete the entry (eslint/prettier family the kit dropped).
   - A vetoed directive is recorded with its reason; nothing else is skipped.

   A missing dependency is not a finding, it is a dead `phpstan.neon` `includes:`
   path, `rector.php` set import, or `tests/Pest.php` plugin that stops the check
   on load. After applying, confirm those three resolve. Runtime `require` /
   `dependencies` are never written, only shown.

3. **Toolchain migration (eslint/prettier to vite-plus).** Trigger: step 2
   produced `remove npm` directives for an eslint/prettier family. Beyond the
   `add`/`remove` already applied:
   - the `deleted-upstream` config files (`eslint.config.*`, `.prettierrc*`,
     `.prettierignore`) are already deleted by Phase 5's P2 arm; confirm none
     remain.
   - set `package.json` `scripts` `build`, `build:ssr`, `dev`, `lint`,
     `test:lint`, `test:unit`, `test:types` to the kit's bodies verbatim.
   - scan `resources/**` for `eslint-disable`, `prettier-ignore`, and imports of
     the removed `resources/js/lib/utils.ts` (`@/lib/utils`, a bare `cn(`).
     List every hit as an app-code follow-up. Do not edit app code.
   - the migration is part of the `frontend-tooling` bucket commit; its decision
     lines name the removed packages and the rewritten scripts.

Regenerate lockfiles with `composer update --lock` and the project's JS package
manager. Commit as a separate `sync-skeleton: dependency lockfiles` commit.

### Phase 7: Verify and report

**Convergence check (the guarantee).** For every path in P1 quality-gate and P2
frontend-tooling that was in scope this run, assert one of:

- **met**: `cmp -s` against `git show origin/<branch>:<path>` passes (byte-equal),
  or the path is a `deleted-upstream` file that is now gone.
- **deviation: `<reason>`**: the user vetoed this file; the reason is recorded.
- **blocked: `<follow-up>`**: convergence needs work this skill will not do
  (app code, `bootstrap/app.php`, `tests/Pest.php`); name the follow-up.

Then re-run `plan-manifest.sh`. It must print nothing, except lines the user
vetoed (each already logged as a deviation). Then check each kit gate `scripts`
alias exists and its body equals the kit's (a monorepo fan-out suffix is
allowed). Any P1/P2 file, directive, or alias that is none of met / deviation /
blocked means the run is **incomplete**: say so in the summary and the report,
and list what is still divergent.

**Available Tooling checklist.** Confirm `composer.json` `scripts` carries each of
these and each at least starts (no "command not found", no missing binary; real
code findings are expected and fine): `composer dev`, `composer lint`, `composer
test:lint`, `composer test:types`, `composer test:type-coverage`, `composer
test:unit`, `composer test:browser`, `composer test`, `composer
update:dependencies`. A missing binary is a manifest-merge bug, not an app-code
to-do.

**README quality-gate checklist.** The kit's README (`#why-this-starter-kit`,
`#available-tooling`) is the acceptance contract. One verdict per line,
`met` / `deviation: <reason>` / `blocked: <follow-up>`:

- PHPStan `level: max`, no baseline: `phpstan.neon` byte-matches the kit.
- 100% line coverage (Pest + Vitest) and 100% type coverage: `phpunit.xml`,
  `vitest.config.ts`, and the `--exactly=100.0` / `--min=100` scripts match.
- `roave/security-advisories` present in `require-dev` (blocks nothing, or name
  what it blocks).
- Rector + hardened Pint: `rector.php`, `pint.json` byte-match the kit.
- `vp lint` + `vp fmt` + `vue-tsc`: vite-plus in `devDependencies`, the eslint /
  prettier family gone, `package.json` gate scripts match the kit.
- Real-browser tests: `pest-plugin-browser` in `require-dev`,
  `tests/Browser/Pest.php` present, Chromium a listed follow-up.
- Essentials defaults: `config/essentials.php` byte-matches; `nunomaduro/essentials`
  in `require` and the `bootstrap/app.php` wiring are follow-ups (never-touch).
- Split CI: the three workflows and `setup-app` byte-match the kit.
- Agent rules: `.ai/rules/**` present.

**Prerequisites for a green gate** (list what the user still has to do by hand):
`npx playwright install chromium`; add the kit's `.gitignore` entries
(`/resources/js/{actions,routes,wayfinder}`, `/.phpunit.cache`, `/storage/pail`,
`/coverage`); add the `.env` keys (`INERTIA_SSR_ENABLED`, `VITE_APP_NAME`,
`APP_FAKER_LOCALE`); wire `tests/Pest.php`; wire `bootstrap/app.php` /
`AppServiceProvider` for Essentials; run `php artisan wayfinder:generate` before
the JS type-check.

**Behavior guarantee.** Run the project's `composer test` chain again.

- Buckets **without** P1/P2/P3: green before and red after is a regression.
  Stop, show the failing output, recommend `git revert`. Do not patch to green.
- With P1/P2/P3: the after-run uses the stricter kit chain (PHPStan level max,
  100% coverage, `strict types everywhere`, `vp lint`). Red is expected and is
  **not** a revert reason. Copy the full `composer test` output verbatim into
  the report as the app-code to-do list.
- If a coverage driver (Xdebug/PCOV) is missing, note the coverage part as
  "unchecked, CI enforces it".

**Run summary (always print this at the end).** Before writing the report file,
show a short at-a-glance summary in the reply so the user sees what happened
without opening anything:

- branch and kit SHA
- one line per bucket commit: `<short-sha> <bucket>` and the file counts
  (added / took-upstream / kept)
- convergence: `converged` if every P1/P2 file, directive, and alias is met, else
  `incomplete` with the count still divergent and the count of recorded deviations
- manifest changes: `plan-manifest.sh` directives applied (add / align / remove
  counts), toolchain migration yes/no, lockfiles regenerated yes/no
- Available Tooling checklist result: which commands start, which do not
- count of open app-code items from `composer test`
- the one revert line

**Report.** Write to `/tmp/sync-skeleton-report-<id>.md` (`<id>` matches the
branch's `sync-skeleton/<id>`). Show the path, ask whether to copy it into the
project. Sections: date, kit SHA, branch, environment check; buckets applied
with per-file decisions; convergence check (per-line met / deviation / blocked)
and any still-divergent P1/P2 items; `plan-manifest.sh` directives applied and
vetoed; toolchain migration and lockfile regeneration; drift report; README
quality-gate checklist; prerequisites for a green gate; manual app-code
follow-ups; "composer test after sync - open app-code items" with the verbatim
output; how to revert (`git revert <sha>` for one bucket,
`git switch <previous> && git branch -D sync-skeleton/<id>` for everything).

## Never (without an explicit instruction)

- Sync a never-touch path automatically.
- Auto-apply an `unclassified` path. Surface it and let the user place it.
- Auto-resolve a conflict in P3-P8. (P1 quality-gate and P2 frontend-tooling are
  kit-authoritative: the kit version is applied by default, with a per-file veto.)
- Overwrite a manifest wholesale, or a lockfile by hand. `composer.json` /
  `package.json` change only through `plan-manifest.sh` directives and the
  `scripts` realignment; lockfiles are regenerated by their tool.
- Bump a runtime dependency (`require` / `dependencies`).
- Change the user's branch, delete their existing `sync-skeleton/...` branch, or
  stash for them.
- Attempt a major framework jump (Laravel major, Inertia major). Point at the
  relevant Boost upgrade command instead.
- Modify `~/Code/laravel-starter-kit` beyond `git fetch`. Read upstream through
  `git show origin/<default>:<path>`.

## Out of scope

- Detecting which kit "version" the project started from.
- Resolving runtime dependency constraints. Shown only.
- The reverse direction (project into kit).
- Running linters or formatters on applied files.
- App code, DB migrations, routes, `bootstrap/**`, domain tests.
