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

### P1 quality-gate

`.github/workflows/lint.yml`, `.github/workflows/static.yml`,
`.github/workflows/tests.yml`, `.github/actions/setup-app/**`,
`.github/dependabot.yml`, `pint.json`, `phpstan.neon`, `rector.php`,
`phpunit.xml`, `.gitattributes`.

Guided manifest (never overwritten wholesale): `composer.json` `scripts` +
`require-dev`, and `composer.lock` regenerated afterwards.

### P2 frontend-tooling

`vite.config.ts`, `vitest.config.ts`, `vitest.setup.ts`, `tsconfig.json`,
`.npmrc`, `.nvmrc`, `pnpm-workspace.yaml`.

Guided manifest: `package.json` `scripts` + tooling `devDependencies`
(`vite-plus`, `vitest`, `@vitest/*`, `vue-tsc`; removed `eslint*` / `prettier*`),
and `package-lock.json` regenerated afterwards.

`deleted-upstream` for `eslint.config.*`, `.prettierrc*`, `.prettierignore`,
`resources/js/lib/utils.ts` (the kit dropped these in the vite-plus move). Keep
the project's copy by default; delete only on request.

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

## Available Tooling (P1 + P2 acceptance)

Source: the kit README `#available-tooling` section. After `quality-gate` +
`frontend-tooling` are applied, `composer.json` `scripts` must carry these and
each must at least start (no "command not found", no missing binary; real code
findings are expected):

- `composer dev` - server + queue + log + Vite together
- `composer lint` - Rector + Pint + vite-plus formatter/linter, fix in place
- `composer test:lint` - read-only: Pint `--test`, Rector `--dry-run`, vp check
- `composer test:types` - PHPStan `level: max` + `vue-tsc`
- `composer test:type-coverage` - 100% type coverage (Pest)
- `composer test:unit` - Pest under a 100% line-coverage gate, then Vitest
- `composer test:browser` - headless Chromium suite
- `composer test` - the full chain in order
- `composer update:dependencies` - Composer + npm bump

`require-dev` must cover every tool the scripts *and the config files* reference.
`phpstan.neon` `includes:` pull in `larastan/larastan`,
`pestphp/pest-plugin-phpstan`, `phpstan/phpstan-mockery` (plus `nesbot/carbon`,
already a runtime dep); `rector.php` uses `driftingly/rector-laravel`;
`tests/Pest.php` uses `pestphp/pest-plugin-laravel`. Full list:
`rector/rector`, `driftingly/rector-laravel`, `laravel/pint`,
`larastan/larastan`, `phpstan/phpstan-mockery`, `pestphp/pest`,
`pestphp/pest-plugin-phpstan`, `pestphp/pest-plugin-laravel`,
`pestphp/pest-plugin-type-coverage`, `pestphp/pest-plugin-browser`,
`nunomaduro/essentials`, `roave/security-advisories`. A missing one leaves a
dead `includes:` path or set import, so the check dies on load, not on a
finding. `package.json` `devDependencies` likewise for `vite-plus`, `vitest`,
`@vitest/coverage-*`, `vue-tsc`.
