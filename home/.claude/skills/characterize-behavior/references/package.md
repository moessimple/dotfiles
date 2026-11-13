# Packages

A package is tested inside an application that Orchestra Testbench builds for each test. Its behaviour is what a consuming application gets: what the service provider registers, the classes and facades it calls, the commands, routes, views, and components it uses, and the configuration it can change. Everything in [pest-setup.md](pest-setup.md) applies, with the differences below.

## Dependencies

A package usually commits no `composer.lock`, and it supports a range of PHP and Laravel versions instead of one.

- **Production dependencies** are the constraints in `require`. They never change: compare `require` in `composer.json` before and after the setup. With a committed lock file, also compare the locked versions as in pest-setup.md.
- **Pest:** the constraint covers the Pest majors that match the PHPUnit majors of the supported Laravel range, for example `"pestphp/pest": "^3.0|^4.0"` when the range resolves to PHPUnit 11 and 12. The same holds for `pestphp/pest-plugin-laravel`. If `config.allow-plugins` does not allow `pestphp/pest-plugin`, add it (`composer config allow-plugins.pestphp/pest-plugin true`): without it, Composer refuses the plugin Pest needs.
- **Without a lock file**, install with `composer update`. Keep a lock file the setup creates out of the diff if the project ignores it, and name it in the report if it does not.
- **Both ends of the range:** after the suite passes, run it once more with the lowest versions, PHP included: install with `composer update --prefer-lowest --prefer-stable` under the lowest PHP version `require.php` allows, and run `php{version} vendor/bin/pest` with that binary, since `vendor/bin/pest` and `composer exec` otherwise start the default PHP. Return with `composer update`. If that PHP version is not installed, run on the default one and say so in the report. A test that fails only on one end pins behaviour that differs between versions: keep the assertion of the newest versions, and record the difference as a finding with both values.

## Test case

If the package has no Testbench test case, add `tests/TestCase.php`:

```php
<?php

namespace {Vendor}\{Package}\Tests;

use {Vendor}\{Package}\{Package}ServiceProvider;
use Orchestra\Testbench\TestCase as Orchestra;

abstract class TestCase extends Orchestra
{
    protected function getPackageProviders($app): array
    {
        return [
            {Package}ServiceProvider::class,
        ];
    }
}
```

List every provider from `extra.laravel.providers` in `composer.json`, and register facades from `extra.laravel.aliases` with `getPackageAliases()`. Map the namespace in `autoload-dev` (`"{Vendor}\\{Package}\\Tests\\": "tests/"`) if it is missing. `tests/Pest.php` extends this class instead of `Tests\TestCase`. Configuration a test needs goes into `defineEnvironment($app)` with `$app['config']->set(...)`, never into a file of the package. If the project already uses `testbench.yaml` and the `WithWorkbench` trait, keep that instead. Test models and other fixtures live in their own files, never in the test case file: `tests/Pest.php` loads the test case before Pest Mutate starts, and a package class a fixture there uses could not be mutated.

## Database

The schema comes from the migrations as the package ships them:

- **Loaded by the provider** (`loadMigrationsFrom()`): `LazilyRefreshDatabase` runs them; the precondition is `vendor/bin/testbench migrate:fresh`.
- **Published stubs** (`*.php.stub`, published for the consuming application): run each stub in `defineDatabaseMigrations()` with `(include __DIR__.'/../database/migrations/{stub}')->up();`, in the order the provider publishes them. The precondition is a test that runs them without an exception.

## Factories

Never add `use HasFactory` to a model of a package: Laravel resolves its factories in the application's namespace, and a consuming application would get a trait that points nowhere. Write factories in `database/factories` in the package's namespace with `protected $model = {Model}::class`, map that namespace in `autoload-dev`, and create records with `{Model}Factory::new()`. If a model already uses `HasFactory`, point factory resolution to the package's namespace in the test case's `setUp()` with `Factory::guessFactoryNamesUsing()`.

## Entry points

Derive the capabilities from what a consuming application can reach:

- **Service provider:** merged configuration and its defaults, container bindings and singletons, publish groups and their tags, registered routes, views, translations, migrations, commands, Blade components, middleware aliases, macros, event listeners
- **Public classes and facades:** the methods a consumer calls, and the exceptions they throw
- **Commands, routes, components, jobs, and events** the package registers or dispatches
- **Configuration:** each key the code reads, with its default and with the values that change behaviour

Test each through the way a consumer reaches it: resolve a binding from the container, call the facade, run the command with `artisan()`, request the route, render the component, assert `config()` values and the files a publish tag copies.

## Coverage and scripts

`<source>` in `phpunit.xml` includes `src` instead of `app`. The `test` script has no `artisan` line:

```json
"test": [
    "@test:unit"
],
```
