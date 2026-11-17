# Target gate

The gate every project reaches. Adjust paths to what the project has and the PHP version to the project's `php` requirement; for a package, [package.md](package.md) lists the differences. Keep everything else as it is, so every project ends up with the same gate.

## Contents

- Composer scripts
- Dev dependencies
- phpstan.neon
- rector.php
- Quality guard
- pint.json
- tests/Unit/ArchTest.php

## Composer scripts

```json
"lint": ["rector", "pint --parallel"],
"test:lint": ["rector --dry-run", "pint --parallel --test"],
"test:audit": ["@composer audit --locked"],
"test:type-coverage": "pest --type-coverage --min=100",
"test:types": "phpstan",
"test:unit": "XDEBUG_MODE=coverage pest --parallel --coverage --exactly=100.0 --fail-on-incomplete",
"test": [
    "@php artisan config:clear --ansi",
    "@test:audit",
    "@test:lint",
    "@test:type-coverage",
    "@test:types",
    "@test:unit"
]
```

With pcov instead of Xdebug, drop `XDEBUG_MODE=coverage`. If the project has a JavaScript frontend with its own lint and audit scripts, add `npm run lint` to `lint`, `npm run test:lint` to `test:lint`, and `npm audit` to `test:audit`. While a threshold is still being raised, the script carries the current value (`--min={current}`, for line coverage the floor characterize-behavior raises), and `phpstan-baseline.neon` holds the errors not fixed yet. A check joins `test` only once it passes, so `test` passes after every commit.

## Dev dependencies

`larastan/larastan`, `rector/rector`, `driftingly/rector-laravel`, `laravel/pint`, `pestphp/pest-plugin-type-coverage`, `pestphp/pest-plugin-phpstan`, `phpstan/phpstan` at `^2.1.41` or newer (the first release with `reportIgnoresWithoutComments`), and `phpstan/phpstan-mockery` when the tests use Mockery. Install them as described in [install.md](install.md).

## phpstan.neon

```neon
includes:
    - vendor/larastan/larastan/extension.neon
    - vendor/nesbot/carbon/extension.neon
    - vendor/pestphp/pest-plugin-phpstan/extension.neon
    - phar://phpstan.phar/conf/bleedingEdge.neon
    # - phpstan-baseline.neon   (only while the baseline exists)

parameters:
    paths:
        - app/
        - bootstrap/app.php
        - config/
        - database/
        - routes/
        - tests/
    level: max
    phpVersion: 80300   # from the project's php requirement, e.g. ^8.3 -> 80300
    reportUnmatchedIgnoredErrors: true
    reportIgnoresWithoutComments: true
```

Add `vendor/phpstan/phpstan-mockery/extension.neon` to `includes` when Mockery is installed. When no `pestphp/pest-plugin-phpstan` release supports the installed Pest major, leave out its include and `tests/`, with a comment in `phpstan.neon` naming that reason. `reportUnmatchedIgnoredErrors` makes PHPStan fail when a baseline entry or ignore no longer matches, so the baseline can only shrink. `reportIgnoresWithoutComments` requires a reason in parentheses on every `@phpstan-ignore` and forbids `@phpstan-ignore-line` and `@phpstan-ignore-next-line`.

`tools` starts at `level: max` without `tests/` in `paths`, and includes `phpstan-baseline.neon` with every error the code has today. Area runs shrink the baseline; the `tests` run adds `tests/` and deletes it.

## rector.php

```php
<?php

use Rector\CodingStyle\Rector\ClassMethod\MakeInheritedMethodVisibilitySameAsParentRector;
use Rector\CodingStyle\Rector\Use_\SeparateMultiUseImportsRector;
use Rector\Config\RectorConfig;
use Rector\Php82\Rector\Class_\ReadOnlyClassRector;
use Rector\Php85\Rector\Property\AddOverrideAttributeToOverriddenPropertiesRector;
use Rector\TypeDeclaration\Rector\StmtsAwareInterface\SafeDeclareStrictTypesRector;
use RectorLaravel\Rector\Class_\AddHasFactoryToModelsRector;
use RectorLaravel\Set\LaravelSetList;

return RectorConfig::configure()
    ->withPaths([
        __DIR__.'/app',
        __DIR__.'/bootstrap/app.php',
        __DIR__.'/config',
        __DIR__.'/database',
        __DIR__.'/public',
        __DIR__.'/routes',
        __DIR__.'/tests',
    ])
    ->withSets([
        LaravelSetList::LARAVEL_ARRAYACCESS_TO_METHOD_CALL,
        LaravelSetList::LARAVEL_ARRAY_STR_FUNCTION_TO_STATIC_CALL,
        LaravelSetList::LARAVEL_CODE_QUALITY,
        LaravelSetList::LARAVEL_COLLECTION,
        LaravelSetList::LARAVEL_CONTAINER_STRING_TO_FULLY_QUALIFIED_NAME,
        LaravelSetList::LARAVEL_ELOQUENT_MAGIC_METHOD_TO_QUERY_BUILDER,
        LaravelSetList::LARAVEL_FACADE_ALIASES_TO_FULL_NAMES,
        LaravelSetList::LARAVEL_FACTORIES,
        LaravelSetList::LARAVEL_IF_HELPERS,
        LaravelSetList::LARAVEL_LEGACY_FACTORIES_TO_CLASSES,
    ])
    ->withComposerBased(laravel: true)
    ->withImportNames(removeUnusedImports: true)
    ->withPreparedSets(
        deadCode: true,
        codeQuality: true,
        // codingStyle: true,   only after a decision under Decisions in QUALITY_GATE.md
        typeDeclarations: true,
        privatization: true,
        // earlyReturn: true,   only after a decision under Decisions in QUALITY_GATE.md
    )
    ->withPhpSets()
    ->withSkip([
        MakeInheritedMethodVisibilitySameAsParentRector::class,
        AddOverrideAttributeToOverriddenPropertiesRector::class,
        ReadOnlyClassRector::class,
        // Adds declare(strict_types=1), which changes runtime behaviour: applied only on a recorded decision.
        SafeDeclareStrictTypesRector::class,
        // Splits `use HasFactory, Notifiable;` as Laravel writes it, and drops the @use annotation above it.
        SeparateMultiUseImportsRector::class,
        // Adds HasFactory to models that have no factory class.
        AddHasFactoryToModelsRector::class,
        // Code not improved yet, see the skip list below.
        ...require __DIR__.'/rector-skip.php',
    ]);
```

Leave out a skipped rule class that does not exist in the installed Rector version. `codingStyle` and `earlyReturn` are optional: they mostly produce large diffs without a shown benefit for the error rate, so they are on only where `QUALITY_GATE.md` records that decision. `tools` writes this configuration whole, without `tests` in the paths until the `tests` run, and with the skip list below, so Rector has nothing to change on the first day.

### Skip list

Rector applies its sets to every path it is given on the command line, even one outside `withPaths()`; only `withSkip()` holds there too. So code whose area has not had its run yet stays in `withSkip()`, and neither `rector --dry-run` in `composer test` nor a call for a single file reports changes in it. `tools` builds the list from the paths of the area table in `tests/CHARACTERIZATION.md`, and adds every other PHP directory under the gate's paths at the same granularity.

The list lives in `rector-skip.php` in the repository root, which `rector.php` spreads into `withSkip()`, so the quality guard can count it without running Rector. It holds only file and directory paths, no rule classes and no wildcards:

```php
<?php

// Code that has not had its area run yet. Entries are only removed, see QUALITY_GATE.md.
return [
    __DIR__.'/app/Http/Controllers/Billing',
    __DIR__.'/app/Models/Invoice.php',
];
```

- **It only shrinks.** A run removes the paths it takes over; nothing is ever added after `tools`. Progress counts the skipped PHP files, which drop with every file taken over.
- **A file inside a skipped directory** is taken over by replacing the directory's entry with an entry for each of its other PHP files. The entries grow, the skipped files drop by one.
- **New files in a skipped directory** are skipped with it until its area run. That is no growth of the list: PHPStan still checks them at `max`, because the baseline holds only the errors of `tools`.
- **Code outside every area** stays in the list until an area takes it over, and is listed in `QUALITY_GATE.md` under Open decisions.

## Quality guard

The baseline and the skip list must not grow, whoever edits them. A test in `composer test` checks both against `quality-gate.lock.json`, which `tools` writes with the baseline's error count and the entries of `rector-skip.php`, relative to the repository root. The test asks for an exact match, so a commit that changes the baseline or the skip list, including one that only fixes a baseline error, updates the lock in the same commit. Every change then shows in the diff of one small file, and a higher count or a new entry there, other than the files that replace a directory entry, is a departure from the gate that review sees.

```json
{
    "phpstan_baseline_errors": 412,
    "rector_skip": [
        "app/Http/Controllers/Billing",
        "app/Models/Invoice.php"
    ]
}
```

The skip list is locked by its entries, not by a file count, so a teammate adding a file to a skipped directory changes nothing in it and does not turn `composer test` red.

`tests/Unit/QualityGuardTest.php` reads the files as text, without a NEON parser or a Rector run:

```php
<?php

use Illuminate\Filesystem\Filesystem;

// The PHPStan baseline and the Rector skip list only shrink. quality-gate.lock.json holds their exact
// state, so every change to either shows in the lock, in the same commit, where review can see it.

it('keeps the PHPStan baseline as locked', function (): void {
    $root = dirname(__DIR__, 2);
    /** @var array{phpstan_baseline_errors: int, rector_skip: list<string>} $lock */
    $lock = (new Filesystem)->json($root.'/quality-gate.lock.json');
    $baseline = is_file($root.'/phpstan-baseline.neon') ? (new Filesystem)->get($root.'/phpstan-baseline.neon') : '';

    preg_match_all('/^\s*count:\s*(\d+)\s*$/m', $baseline, $counts);

    expect(array_sum(array_map(intval(...), $counts[1])))->toBe($lock['phpstan_baseline_errors']);
});

it('keeps the Rector skip list as locked', function (): void {
    $root = dirname(__DIR__, 2);
    /** @var array{phpstan_baseline_errors: int, rector_skip: list<string>} $lock */
    $lock = (new Filesystem)->json($root.'/quality-gate.lock.json');
    /** @var list<string> $paths */
    $paths = require $root.'/rector-skip.php';

    $entries = array_map(fn (string $path): string => substr($path, strlen($root) + 1), $paths);
    $locked = $lock['rector_skip'];
    sort($entries);
    sort($locked);

    expect($entries)->toBe($locked);
});
```

Add `declare(strict_types=1);` when the project's files use it. The test is written to pass PHPStan at `max`, Rector, and Pint as it stands, so the `tests` run has nothing to change in it. Once the `tests` run deletes the baseline and empties the skip list, the lock holds 0 and an empty list, and stays there.

A feature branch that fixes a baseline error removes its entry, because `reportUnmatchedIgnoredErrors` demands it, and lowers the count in the lock with it. When that meets an open `quality-gate/*` run, resolve the merge conflict by regenerating the baseline, keeping only the skip entries both sides still have, and writing the resulting count and entries into the lock.

A project whose `tools` run predates the guard gets it in the first commit of its next run: move the paths from `withSkip()` in `rector.php` into `rector-skip.php`, spread it back in, write the guard and the lock with today's values, and add the lock rule to the agent instructions as `tools` does.

## tests/Unit/ArchTest.php

Pest's built-in architecture presets, run by `test:unit` like any other test:

```php
<?php

arch()->preset()->php();
arch()->preset()->security();
arch()->preset()->laravel();
```

- `php` forbids debugging leftovers such as `die` and `var_dump`, and deprecated PHP functions. It needs the `intl` extension; without it, leave `php()` out and say so in the report.
- `security` forbids functions such as `eval`, `exec`, `md5`, `sha1`, `rand`, `unserialize`, and `extract`.
- `laravel` enforces Laravel's conventions: suffixes and base classes of controllers, form requests, commands, policies, and providers, only resource action names as public controller methods, `ShouldQueue` on mailables and jobs, no `env()` outside configuration, no `dd()` or `dump()`.
- A package uses only `php` and `security`: the `laravel` preset assumes the `App` namespace of an application.
- `strict` is not part of the gate: it requires `declare(strict_types=1)` and `final` classes, which change behaviour or a package's public API.

Most violations cannot be fixed without changing behaviour: replacing `md5()` changes stored hashes, adding `ShouldQueue` moves a mail onto the queue, renaming a model changes its table name. So the presets start like a baseline: each existing violation is listed with `->ignoring(...)` (the class, namespace, or function) and a comment naming the reason, and goes into `QUALITY_GATE.md` as an open decision. The list only ever shrinks; a new violation fails the test.

## pint.json

The formatting rules, applied in one go:

```json
{
    "preset": "laravel",
    "rules": {
        "array_push": true,
        "backtick_to_shell_exec": true,
        "fully_qualified_strict_types": true,
        "global_namespace_import": {
            "import_classes": true,
            "import_constants": true,
            "import_functions": true
        },
        "lowercase_keywords": true,
        "lowercase_static_reference": true,
        "modernize_types_casting": true,
        "new_with_parentheses": false,
        "no_multiple_statements_per_line": true,
        "no_superfluous_elseif": true,
        "no_useless_else": true,
        "ordered_class_elements": {
            "order": [
                "use_trait", "case", "constant", "constant_public", "constant_protected", "constant_private",
                "property_public", "property_protected", "property_private",
                "construct", "destruct", "magic", "phpunit",
                "method_abstract", "method_public_static", "method_public", "method_protected_static",
                "method_protected", "method_private_static", "method_private"
            ],
            "sort_algorithm": "none"
        },
        "ordered_interfaces": true,
        "ordered_traits": true,
        "protected_to_private": true,
        "self_accessor": true,
        "self_static_accessor": true,
        "visibility_required": true
    }
}
```

`tools` starts with `"exclude": ["tests"]` and without two rules of the set above, which can still change behaviour and which the tests only reliably catch at full coverage. Both are recorded under Deferred, and the `tests` run turns them on one at a time:

- `ordered_traits` sorts a class's traits alphabetically, and Laravel boots a model's traits (`boot{Trait}`, `initialize{Trait}`) in the order they are used, so the order in which model events and global scopes are registered can change.
- `ordered_class_elements` reorders properties across visibilities, which changes the order of `(array)` casts, `get_object_vars($this)`, and `serialize()`.

When turning one on, run the mutation check over every class it changed. Where either changes what the tests observe, undo that part. Pint cannot turn a rule off for one file: either keep the file out of Pint with `notPath` (it is then not formatted at all) or leave the rule out of `pint.json`. Both depart from the gate and go into the report as decisions.

Four further rules of the gate change behaviour at runtime. Each is added on its own, only after a decision:

| Rule | Behaviour it changes |
|---|---|
| `declare_strict_types` | no implicit type coercion: `"5"` passed to an `int` parameter throws a `TypeError` |
| `date_time_immutable` | `DateTime` becomes `DateTimeImmutable`; code relying on `modify()` changing the object breaks |
| `mb_str_functions` | `strlen()` and friends become `mb_*`; results differ for multibyte characters |
| `strict_comparison` | `==` becomes `===`; results differ when the types differ |

Rector's `SafeDeclareStrictTypesRector` belongs to the `codeQuality` set and adds the same declaration as `declare_strict_types`, so it is skipped until that decision.
