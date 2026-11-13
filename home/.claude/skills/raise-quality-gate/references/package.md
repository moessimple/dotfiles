# Packages

A package supports a range of PHP and Laravel versions and is used by applications the skill cannot see. Two things follow: every step has to hold at both ends of the range, and the public API must stay compatible, because a consumer's code that extends or calls the package is part of its behaviour. Everything in the skill applies, with the differences below.

## Dependencies

- **Production dependencies** are the constraints in `require`. They never change. Compare `require` in `composer.json` before and after each installation; with a committed lock file, also compare the locked versions as in [install.md](install.md).
- **Tool constraints** cover the supported range: Larastan, Rector plugins, and Pest plugins in the majors that match each end, for example `"pestphp/pest-plugin-type-coverage": "^3.0|^4.0"` when the range resolves to Pest 3 and 4. Larastan 3 covers every Laravel version from 11 on, the lowest characterize-behavior supports, and Larastan 2 cannot be used: it runs on PHPStan 1, which does not know `reportIgnoresWithoutComments`.
- **Without a lock file**, install with `composer update`. Keep a lock file the run creates out of every commit if the project ignores it.
- **The range resolves and runs:** after each installation, `composer update --prefer-lowest --prefer-stable --dry-run` must still succeed, and each tool must run with the lowest versions installed. A lowest tool version that resolves but fails (such as a Rector plugin that references a class its lowest Rector lacks) gets a higher lower bound in `require-dev`, listed in the report. If a tool makes the lowest versions unresolvable, take its older major or stop with a blocker.

## Both ends of the range

Before every commit, run `composer test` with the newest versions, and the tests once with the lowest versions, PHP included: `composer update --prefer-lowest --prefer-stable` under the lowest PHP version `require.php` allows, `php{version} vendor/bin/pest` with that binary (`vendor/bin/pest` alone starts the default PHP), then `composer update` back. A commit passes only when both pass. If that PHP version is not installed, run on the default one and say so in the report.

Run Rector with the lowest versions installed. `withPhpSets()` reads the lowest PHP version from `require.php`, but the Composer-based Laravel sets read the installed `laravel/framework`, which a package only gets through Testbench: with the newest versions installed, Rector applies rules for a Laravel version the package does not require, such as attributes the lowest version does not know. And because `composer test` runs `rector --dry-run` with the newest versions, it would then demand those rules. So a package replaces `withComposerBased(laravel: true)` with the level set of its lowest Laravel version, which does not depend on what is installed:

```php
->withSets([
    // ... the Laravel sets of the gate
    // The lowest supported Laravel version, independent of the one installed.
    LaravelLevelSetList::UP_TO_LARAVEL_120,
])
```

## Configuration

- **PHPStan:** `phpVersion` covers the range, from `require.php` to the newest PHP version the package supports:

  ```neon
  phpVersion:
      min: 80200
      max: 80599
  ```

  Larastan boots the package through Testbench by itself: it registers the providers from `extra.laravel.providers` or `testbench.yaml`. Paths are `src/`, `config/`, `database/`, and `tests/`, as far as they exist. Larastan takes Testbench's application as the configuration directory, so it reports `env()` in the package's `config/` and cannot read its values: point it there with `configDirectories: [config/]`.

  PHPStan analyses a trait only in a class that uses it. While `tests/` stays out (see gate.md), add the test file whose class uses the package's trait, such as `tests/TestCase.php`, with a comment; without it the trait is reported as unused and not analysed.
- **Rector:** paths are `src`, `config`, `database`, and `tests`, as far as they exist.
- **Composer scripts:** `test` has no `artisan` line. Without a committed lock file, `test:audit` is `@composer audit` without `--locked`, and checks the newest versions it installs. An advisory that only a higher lower bound in `require` would fix is an open decision, because raising it drops support for those versions.

## Public API

A change that compiles inside the package can still break a consuming application. Before every commit, compare the public API with the last release using [Roave BackwardCompatibilityCheck](https://github.com/Roave/BackwardCompatibilityCheck). It needs a newer PHP than many packages support and its own dependencies, so install it outside the project, once, and run it from the package root:

```bash
composer require roave/backward-compatibility-check --working-dir="${XDG_CACHE_HOME:-$HOME/.cache}/raise-quality-gate/tools"
"${XDG_CACHE_HOME:-$HOME/.cache}"/raise-quality-gate/tools/vendor/bin/roave-backward-compatibility-check --from={last release tag} --to=HEAD
```

Without a release tag, compare with the commit the branch started from. Every `[BC]` line it prints is a breaking change; it also catches what the list below misses, such as an optional parameter added to a method a consumer may override. In a package, these are breaking changes and go into the report as open decisions, never into a commit on the skill's own initiative:

- a return type added to a method of an interface, or to a public or protected method of a class that is not `final`: a consumer's implementation or subclass without that type stops compiling
- a parameter type added to a public method or function: a consumer passing a value of another type can get a `TypeError`
- anything renamed, removed, or made less visible that is public, or protected in a class that is not `final`
- `final` or `readonly` added to a class or method
- on a model that is not `final`: a scope made protected or turned into a `#[Scope]` method, and `$casts` moved to `casts()`, which a subclass overriding `$casts` would then get merged in (`MakeModelAttributesAndScopesProtectedRector`, `ScopeNamedClassMethodToScopeAttributedClassMethodRector`, `ModelCastsPropertyToCastsMethodRector`)

In those places, give PHPStan the type as PHPDoc (`@param`, `@return`) instead: it binds no consumer. Keep Rector out with an entry in `withSkip()` naming the rule and the path, mark the native type gap with `@pest-ignore-type` for the type coverage, and record each place with its reason. Native types on `@internal` classes, private members, and `final` classes are safe.

A breaking change changes the package's major version. If the people deciding want them, they apply them together on top of the gate, for the next major release.
