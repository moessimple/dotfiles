# Profile: `laravel-starter-kit`

Human reference for the `sync-skeleton` skill when the target project was
bootstrapped from `moessimple/laravel-starter-kit`.

The machine truth for path classification is the `case` cascade in
`scripts/classify.sh`. `tests/claude/skills/sync-skeleton/buckets.bats` keeps
this file and that cascade in sync: every bucket name here must appear there and
the other way round, and every tracked kit path must land in exactly one bucket.

## Upstream

- Repo: `moessimple/laravel-starter-kit`
- Origin match (regex): `github\.com[:/]moessimple/laravel-starter-kit(\.git)?$`
- Default branch: `git -C <kit> symbolic-ref refs/remotes/origin/HEAD`, else probe
  `main` then `master`.
- Local clone preference: if `~/Code/laravel-starter-kit` exists and its `origin`
  matches the regex above, `git fetch origin` there and compare against
  `origin/<default-branch>`. Never check out, reset, or otherwise write that
  clone. Otherwise `git clone --filter=blob:none` into a `mktemp -d`.

## Descendant markers (`preflight.sh`)

The target is treated as a descendant of this skeleton only when all three hold:

1. `boost.json` exists at the target root.
2. `.ai/rules/` exists at the target root.
3. An Inertia + Vue signature is present: `resources/js/app.ts` exists, or
   `@inertiajs/vue3` appears in `package.json`.

## Buckets (priority order = catalog order)

P1 and P2 preselect `new` **and** `differs`. P3 through P8 preselect only `new`.

**P1 and P2 are kit-authoritative.** These two buckets are the kit's whole point
(`README#why-this-starter-kit`), so their sync is convergence, not negotiation:
the kit wins every `differs`, `deleted-upstream` files are removed, and the
dependency sets are made equal to the kit's via `plan-manifest.sh`. Per-file /
per-dependency veto is allowed and recorded. P3-P8 stay conservative.

### P1 quality-gate

`.github/workflows/lint.yml`, `.github/workflows/static.yml`,
`.github/workflows/tests.yml`, `.github/actions/setup-app/**`,
`.github/dependabot.yml`, `pint.json`, `phpstan.neon`, `rector.php`,
`phpunit.xml`, `.gitattributes`.

Manifest (never overwritten wholesale): `composer.json` `scripts` realigned to
the kit, `require-dev` converged via `plan-manifest.sh` (`add` / `align`), and
`composer.lock` regenerated afterwards.

### P2 frontend-tooling

`vite.config.ts`, `vitest.config.ts`, `vitest.setup.ts`, `tsconfig.json`,
`.npmrc`, `.nvmrc`, `pnpm-workspace.yaml`.

Manifest: `package.json` `scripts` realigned to the kit, `devDependencies`
converged via `plan-manifest.sh` (`add` / `align` / `remove`), and
`package-lock.json` regenerated afterwards.

`deleted-upstream` for `eslint.config.*`, `.prettierrc*`, `.prettierignore`,
`resources/js/lib/utils.ts` (the kit dropped these in the vite-plus move).
Kit-authoritative: **deleted** by default, veto to keep. When `plan-manifest.sh`
emits `remove npm` for an eslint/prettier family, the full toolchain migration
(SKILL.md Phase 6) runs: strip the family, add vite-plus, rewrite the
`package.json` gate scripts, list `eslint-disable` / `prettier-ignore` /
`@/lib/utils` hits in `resources/**` as app-code follow-ups.

### P3 essentials

`config/essentials.php`. Conceptually part of the quality gate (runtime
hardening). Report-only pointers: `nunomaduro/essentials` in `composer.json`
`require`, and the related `bootstrap/app.php` lines. Risk: strict models /
`preventStrayRequests` can break existing app code, so always present it and let
the baseline comparison catch regressions.

### P4 arch-tests

`tests/Arch/**`, `tests/ArchTest.php`, `tests/Http/WelcomeTest.php`,
`tests/Console/.gitkeep`, `tests/Unit/*/.gitkeep`, and `tests/Browser/Pest.php`
(the browser test-suite bootstrap, not the browser domain tests).
`deleted-upstream` for `tests/Feature/ExampleTest.php`,
`tests/Unit/ExampleTest.php`.

Report-only Pest patterns (`tests/Pest.php` itself stays never-touch):
`freezeDeterministicState`, `LazilyRefreshDatabase` in Http/Console,
`arch()->preset()`, and the `require_once __DIR__.'/Browser/Pest.php'` line that
wires the applied `tests/Browser/Pest.php` in.

### P5 frontend-test-setup

`resources/js/pages/Welcome.test.ts`.

### P6 agent-rules

`.ai/rules/**`, `.claude/skills/**`, `.mcp.json`, `boost.json`. Always treat
`.ai/rules/actions.md` and `.ai/rules/index.md` as `differs` with no auto
proposal, even here.

### P7 welcome-page

`resources/js/pages/Welcome.vue`, `resources/views/app.blade.php`,
`resources/css/app.css`. Only meaningful for a very fresh descendant.

### P8 misc-config

`config/inertia.php`, `resources/js/app.ts`, `resources/js/types/**`,
`.editorconfig`.

## drift-only (show the diff, never write, never preselect)

`.gitignore`, `.env.example`, `CLAUDE.md`.

## never-touch

`app/**`, `database/**` (except `database/.gitignore`), `routes/**`,
`bootstrap/**` (except `bootstrap/cache/.gitignore`), `config/**` except
`config/essentials.php` and `config/inertia.php`, `tests/Pest.php`,
`tests/Browser/**` except `tests/Browser/Pest.php` (arch-tests),
`tests/TestCase.php`, `tests/Unit/Models/**`. `composer.json` / `package.json`
`require` / `dependencies` (runtime) are shown, never written.

## not-in-scope (framework boilerplate or project-owned; never in the catalog)

`artisan`, `public/**`, `storage/**`, `bootstrap/cache/.gitignore`,
`database/.gitignore`, `LICENSE`, `README.md`. The kit ships no git hooks, no
PR/issue templates and no `Makefile`; there is nothing to sync there.

## unclassified (matched no cascade arm)

Any tracked kit path that falls through every arm of `bucket_for` in
`classify.sh`: the kit added a file the map does not know yet (a new
`resources/js/components/**` file, a new root dotfile, a new `config/*.php` that
is not `essentials` or `inertia`). It is never folded into `not-in-scope`
silently. `classify.sh` emits bucket `unclassified`; the skill shows it in its
own block for a manual decision and never auto-applies it. When one appears, add
an arm to the cascade and a line to the relevant section above, then regenerate
`SYNC_SKELETON_KIT_MANIFEST` in `tests/support/sync_skeleton_helper.bash`.

## P1 + P2 acceptance (the guarantee)

Source: the kit README `#why-this-starter-kit` and `#available-tooling`. After
P1 + P2 are applied, Phase 7's convergence check must reach a verdict of `met`,
`deviation: <reason>` (user vetoed), or `blocked: <follow-up>` (app-code work)
for every item. Nothing may be silently divergent.

**Config files** byte-match `git show origin/<branch>:<path>`: `phpstan.neon`,
`phpunit.xml`, `pint.json`, `rector.php`, `.gitattributes`, the three
`.github/workflows/*.yml`, `.github/actions/setup-app/**`, `.github/dependabot.yml`,
`vite.config.ts`, `vitest.config.ts`, `vitest.setup.ts`, `tsconfig.json`,
`.npmrc`, `.nvmrc`, `pnpm-workspace.yaml`, `config/essentials.php`.

**Scripts** carry the kit's bodies (a monorepo fan-out suffix is allowed) and
each at least starts: `composer dev`, `composer lint`, `composer test:lint`,
`composer test:types`, `composer test:type-coverage`, `composer test:unit`,
`composer test:browser`, `composer test`, `composer update:dependencies`; and in
`package.json` `build`, `build:ssr`, `dev`, `lint`, `test:lint`, `test:unit`,
`test:types`.

**Dependencies**: `plan-manifest.sh` re-run prints nothing (bar vetoed lines).
That covers `roave/security-advisories`, `pest-plugin-browser`, and the eslint /
prettier removal. The parts that break on *load* rather than as a finding, to
confirm after merging: `phpstan.neon` `includes:` (larastan, pest phpstan plugin,
phpstan-mockery), `rector.php` set imports (rector-laravel), `tests/Pest.php`
plugins (pest-plugin-laravel).

**Blocked (named follow-ups, never done by the skill)**: `npx playwright install
chromium`; `nunomaduro/essentials` in `require` and its `bootstrap/app.php`
wiring; `tests/Pest.php` wiring; app-code changes for PHPStan max / 100% coverage
/ strict types. These make the verdict `blocked`, not `incomplete`.
