# Pest setup

The setup gives every characterization test the same deterministic starting point, keeps the project's test layout (`tests/Feature` for the tests per entry point, `tests/Unit` for the few classes no entry point reaches), and isolates the test environment from external systems. It deliberately leaves out architecture presets, browser tests, type coverage, and static analysis, which belong to modernization rather than characterization.

## Contents

- Install
- tests/Pest.php
- phpunit.xml
- Database
- Composer scripts
- Commands

Never run `pest --init`: it can overwrite an existing `phpunit.xml` or `tests/Pest.php`. Write from these templates and keep what the project already has.

## Install

The tests must run against the production dependencies as they are, so installing Pest must not move them. Never use `--with-all-dependencies` (`-W`): it upgrades production packages, up to the framework itself. A package without a lock file follows [package.md](package.md) instead of steps 1 and 4.

1. Record the production packages: `composer show --locked --no-dev --format=json`.
2. Choose the Pest major that matches the locked PHPUnit major: PHPUnit 11 → Pest 3, PHPUnit 12 → Pest 4, PHPUnit 13 → Pest 5. Without PHPUnit in the lock file, take the newest Pest that resolves. PHPUnit 10 or older never reaches this step: the version check in the skill stops before.
3. Add Pest without updating, then update only Pest and the existing test packages:

   ```bash
   composer require --dev "pestphp/pest:^{major}.0" "pestphp/pest-plugin-laravel:^{major}.0" --no-update
   composer update pestphp/pest pestphp/pest-plugin-laravel phpunit/phpunit nunomaduro/collision --with-dependencies --minimal-changes
   ```

4. Compare the production packages with step 1.
   - **No change:** continue.
   - **Any change, patch level included:** first try the older minor versions of the same Pest major, newest first (`"pestphp/pest:~{major}.{minor}.0"`), with `--dry-run`, and take the first one that leaves every production package unchanged. If none does, it is a blocker: restore `composer.json` and `composer.lock` with `git checkout`, run `composer install`, and report which package Pest would move.

If no Pest version resolves, that is a blocker too.

## tests/Pest.php

If the file exists, keep its content and add only what is missing.

```php
<?php

use Illuminate\Foundation\Testing\LazilyRefreshDatabase;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Process;
use Illuminate\Support\Sleep;
use Illuminate\Support\Str;
use Tests\TestCase;

// Every test starts from the same state: real random strings and UUIDs, a hard
// failure on any outbound HTTP request or process the test did not fake, no real sleeping,
// and frozen time. LazilyRefreshDatabase migrates only for tests that touch the database.
// Fakes for storage, mail, events, and queues belong in the tests that need them.
pest()->extend(TestCase::class)
    ->use(LazilyRefreshDatabase::class)
    ->beforeEach(function (): void {
        Str::createRandomStringsNormally();
        Str::createUuidsNormally();
        Http::preventStrayRequests();
        Process::preventStrayProcesses();
        Sleep::fake();
        $this->freezeTime();
    })
    ->in('Feature', 'Unit');
```

Unit tests isolate one class but may boot the framework, so the chain applies to both directories. Match the project's style for `declare(strict_types=1)`: add it only if the project's PHP files use it. For a package, `Tests\TestCase` is the package's Testbench test case from [package.md](package.md).

Existing class-based tests (`class ... extends TestCase`) are not affected by `pest()->extend()` and keep running as they are.

Create `tests/Feature` and `tests/Unit` if they are missing, each with an empty `.gitkeep` while it has no tests: Pest stops when a directory named in `tests/Pest.php` or `phpunit.xml` does not exist.

## phpunit.xml

If the file exists, keep its suites and settings, and add what is missing from the following. A suite that already covers `tests/` includes `tests/Unit` and `tests/Feature`: keep it instead of adding the two suites, or every test runs twice.

```xml
<testsuites>
    <testsuite name="Unit">
        <directory>tests/Unit</directory>
    </testsuite>
    <testsuite name="Feature">
        <directory>tests/Feature</directory>
    </testsuite>
</testsuites>
<source>
    <include>
        <directory>app</directory>
    </include>
</source>
<php>
    <env name="APP_ENV" value="testing"/>
    <env name="APP_MAINTENANCE_DRIVER" value="file"/>
    <env name="BCRYPT_ROUNDS" value="4"/>
    <env name="BROADCAST_CONNECTION" value="null"/>
    <env name="CACHE_STORE" value="array"/>
    <env name="DB_CONNECTION" value="sqlite"/>
    <env name="DB_DATABASE" value=":memory:"/>
    <env name="DB_URL" value=""/>
    <env name="MAIL_MAILER" value="array"/>
    <env name="QUEUE_CONNECTION" value="sync"/>
    <env name="SESSION_DRIVER" value="array"/>
    <env name="PULSE_ENABLED" value="false"/>
    <env name="TELESCOPE_ENABLED" value="false"/>
    <env name="NIGHTWATCH_ENABLED" value="false"/>
</php>
```

For a package, `<source>` points at `src` instead of `app`.

If the test environment has no application key (no `APP_KEY` in `phpunit.xml`, `.env.testing`, or the environment), the application cannot encrypt and tests fail with `MissingAppKeyException`. Add a key used only for tests:

```xml
<env name="APP_KEY" value="base64:{32 random bytes, base64-encoded}"/>
```

Generate it with `php -r 'echo "base64:".base64_encode(random_bytes(32)), PHP_EOL;'`. It must never be a key used anywhere else.

Without any `.env` file, the environment loader emits a PHP warning on every test that boots the application, so Pest reports "warnings" instead of "passed". If the project has neither `.env` nor `.env.testing`, add a `.env.testing` without values: with `APP_ENV=testing`, Laravel reads it instead of `.env`. Explain it in the file, because an empty file looks removable:

```
# Intentionally without values: the test configuration lives in phpunit.xml.
# With APP_ENV=testing, Laravel reads this file instead of .env, so tests run
# without a .env file and without "file not found" warnings.
```

`DB_CONNECTION` and `DB_DATABASE` follow the Database section below.

## Database

Tests pin what the database engine does, and engines differ in ways a characterization would pin wrongly: case sensitivity of comparisons, order without `ORDER BY`, JSON columns, strict mode, date functions. So the tests run on the engine production uses (`DB_CONNECTION` in `.env.example` and the default in `config/database.php`), when a server for it answers locally:

- Use a database of its own, `{name}_testing`, where `{name}` is the database `.env.example` names. Never use the database the project's `.env` points to: `LazilyRefreshDatabase` drops every table in it. Create the testing database when it is missing; with `--parallel`, Laravel creates one per process from it.
- Set `DB_CONNECTION` and `DB_DATABASE` in `phpunit.xml`, and nothing else: host, port, and credentials come from the environment.
- If no server for that engine answers, or the project already uses SQLite, use SQLite in memory as in `phpunit.xml` above, and say in the report that the tests ran on SQLite while production uses another engine.

## Composer scripts

`composer test` runs the coverage gate. Replace the project's `test` script and add `test:unit`, leaving every other script as it is:

```json
"test": [
    "@php artisan config:clear --ansi",
    "@test:unit"
],
"test:unit": "XDEBUG_MODE=coverage pest --parallel --coverage --exactly=100.0 --fail-on-incomplete"
```

With pcov instead of Xdebug, drop `XDEBUG_MODE=coverage`. For a package, drop the `artisan` line. Later quality steps (audit, lint, static analysis, browser tests) belong into `test` as further `@test:*` entries, not into this skill. Edit only these entries and keep the rest of `composer.json` formatted as it was.

## Commands

```bash
vendor/bin/pest                                                   # suite
vendor/bin/pest --filter="{test name}"                            # one test
XDEBUG_MODE=coverage vendor/bin/pest --coverage --exactly=100.0   # coverage gate
```

With pcov instead of Xdebug, drop `XDEBUG_MODE=coverage`.
