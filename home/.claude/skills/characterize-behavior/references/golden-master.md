# Golden master

The targeted tests pin the behaviour someone thought of. The golden master records everything an entry point produces, including for inputs nobody wrote a test for, and every later change has to produce exactly the same. It uses Pest's built-in snapshots (`toMatchSnapshot()`, stored under `tests/.pest/snapshots`), so it needs no extra package.

## Recording

Record it against the current code, before anything changes, with one test file per entry point under `tests/GoldenMaster/`, mirroring the paths of the targeted tests. Add `GoldenMaster` to the directories in `tests/Pest.php`, and add a suite for it to `phpunit.xml`, unless a suite already covers `tests/`: without a path, Pest runs only the suites `phpunit.xml` names, so neither `composer test` nor `--group=golden-master` would find the files.

```xml
<testsuite name="GoldenMaster">
    <directory>tests/GoldenMaster</directory>
</testsuite>
```

The golden master resets the database with `DatabaseMigrations` (see Auto-increment ids below). Tests of other suites that share a process with it can then fail, depending on order. Exclude its group from the default run in `phpunit.xml` (`<groups><exclude><group>golden-master</group></exclude></groups>`) and run it on its own with a Composer script that `test` calls: `"test:golden-master": "pest --parallel --testsuite=GoldenMaster --group=golden-master --fail-on-incomplete"`. `test:unit` then measures coverage without it, which it does not need.

A recording test looks like this:

```php
<?php

use Illuminate\Support\Facades\DB;

beforeEach(function (): void {
    // A fixed clock, so snapshots do not change from one day to the next.
    $this->travelTo('2000-01-01 00:00:00');
});

it('keeps what storing a product produces', function (array $input) {
    $response = $this->post(route('admin.products.store'), $input);

    expect([
        'status' => $response->status(),
        'body' => $response->getContent(),
        'products' => DB::table('products')->get()->map(fn ($row) => (array) $row)->all(),
    ])->toMatchSnapshot();
})->with([
    'valid' => [['name' => 'Desk Lamp']],
    'missing key' => [[]],
    'empty string' => [['name' => '']],
    'array instead of string' => [['name' => ['a', 'b']]],
    'very long string' => [['name' => str_repeat('x', 1000)]],
    'unicode' => [['name' => 'Lampe äöü 🚀']],
])->group('golden-master');
```

- **Entry points:** every entry point of the application, not only HTTP (characterize-behavior collects them with its `scripts/inventory.sh` and keeps them in `tests/CHARACTERIZATION.md`): every route (including those a package such as Fortify registers for the application), every Livewire or Volt component action, every console command the application defines (`artisan()`; snapshot exit code, output, and changes), every scheduled task, every queued job and listener (dispatched or handled directly), and every broadcast channel authorization. The golden master is complete when each of them has a file; list any left out, with the reason, in the report.
- **Scenarios:** per entry point, the main path, each failure the code distinguishes, and for each parameter that reaches a decision the unexpected inputs from the dataset above that fit it, plus zero and negative numbers for numeric ones. A parameter the code only stores or shows needs no odd inputs of its own: every field times every odd input multiplies snapshots without pinning another decision. Each scenario creates its own records, as in the targeted tests.
- **What goes into the snapshot:** what an actor or a later process observes, in a form that changes only when that observation changes: status, headers that matter (redirect target), the rows of every table the entry point touches, what the fakes recorded (mail, notifications, dispatched jobs and events), a JSON or CLI body as it is, and for an HTML page what a visitor reads and where it leads: the visible text of its main content (`<main>`, or `<body>` when the page has none) line by line plus `aria-label`, `placeholder`, link and form targets, and the state of form fields (`value`, `checked`, `selected`, `disabled`), which a visitor sees as well, without markup, CSS classes, scripts, or asset tags (PHP's built-in `Dom\HTMLDocument` extracts this without a package). The layout around the main content (navigation, footer) is the same on every page: record it once per role in a scenario of its own, so a changed menu label changes one snapshot, not every page. For a Livewire update, its effects (redirects, dispatched events, modals) and the main content it renders, not the component's dehydrated state or any other part of Livewire's internal format. Raw markup would fail on every package update that changes classes or attributes, a false alarm that teaches people to update snapshots blindly. Take two snapshots per scenario: the structured values first, then the body or page text as a plain string, so a diff stays readable.
- **Shared helpers first:** before the first entry point file, write the baseline in `tests/Pest.php` (trait, clock, deterministic strings and UUIDs) and the few helpers every file needs (reading table rows, building the snapshot of a response, replacing uncontrollable values). Record one file with them, run it three times as described below, and pass the project's static analysis over it. Only then write the rest: a change to the helpers after that means recording every snapshot again.
- **Explicit data:** a snapshot is only as stable as the records behind it. Every attribute that reaches the snapshot is set in the test, including those a targeted test leaves to the factory (names, emails, titles, descriptions), and so are the records a factory creates through relations or states (such as a state that creates related users). Pass these values to the factory call (`create([...])`, `state()`, `for()`), as Laravel documents. Do not seed Faker or replace it in the container: a seed that holds for one test alone can still differ inside the suite, and replacing Faker is not a documented API. Faker produces new values on every run, so a value the test left to Faker makes the second run below fail; that is the check.
- **Auto-increment ids:** a rolled-back transaction (`RefreshDatabase`, `LazilyRefreshDatabase`) does not reset them on MySQL or PostgreSQL, and `DatabaseTruncation` skips tables that are empty, whose counters keep running. So the golden master uses `DatabaseMigrations`, which Laravel documents for a complete reset: it recreates the tables before each test and rolls them back afterwards, so ids start at 1 in every test, and the next test with another trait migrates again. If that is too slow, replace the ids with placeholders through an expectation pipe instead (below), accepting that the snapshot no longer shows which record refers to which.
- **Local environment:** a snapshot must not depend on the machine that records it. Run the recorded golden master once more under a different local state that should not matter (for Laravel with Vite, with and without `public/hot`).
- **The fixed date:** choose it after reading the seeders and validation the tests run, not before: a seeder that rejects dates in the future, or data that must lie before or after "now", fails against an arbitrary date.
- **Dynamic values:** the clock is fixed above. Random strings and UUIDs become deterministic through the documented `Str::createRandomStringsUsing()` and `Str::createUuidsUsing()` with a counter (unique columns need distinct values), reset afterwards with `Str::createRandomStringsNormally()` and `Str::createUuidsNormally()`. Values the test cannot control, such as CSRF tokens or absolute paths, are replaced with a fixed placeholder by an expectation pipe on `toMatchSnapshot`, the way Pest's snapshot documentation shows, never by leaving the field out. If the project's static analysis cannot type `$this->value` inside the pipe closure at its level, replace the values with a plain function before `toMatchSnapshot()` instead of lowering the analysis. Values that commonly need a placeholder: password hashes, measured durations, and anything signed with the application key that still reaches the snapshot. Replace only the varying part, keyed by name or by pattern, so the rest of the value stays pinned.
- **For a package**, the entry points are what a consuming application reaches: the public classes and functions, facades, commands, configuration, and published files, called the way a consumer calls them.

Run `vendor/bin/pest --group=golden-master` once to write the snapshots (reported as incomplete), then twice with `--order-by=random`: both must pass. A snapshot that differs between these runs rests on data the test does not control; make that data explicit, never update the snapshot. Then run `composer test:golden-master` once, so it also passes in parallel, the way the gate runs it.

**In CI.** When the project has a CI workflow that runs the test suite, add one step to that job that runs `composer test:golden-master`, after the step that runs the other tests. Add it only when that job uses the database engine the snapshots were recorded on: another engine records other values (booleans, order, dates), and the step would fail for reasons other than a behaviour change. Otherwise add nothing and say in the report that CI does not run the golden master, and why.

## Checking

`test:golden-master` runs with `--fail-on-incomplete`, so a missing snapshot fails instead of being written silently. A snapshot that differs means the behaviour changed: undo the change, never update the snapshot. Running `--update-snapshots`, or changing a file under `tests/.pest/snapshots` after the recording, lowers the bar.

For a package, the golden master runs with the newest versions only: Pest names snapshot files differently between majors, so the run with the lowest versions excludes it with `--exclude-group=golden-master`.

## Afterwards

The golden master stays as the broad net for as long as it protects something the targeted tests do not. Commit the snapshots in a commit of their own, after reviewing each file, so the recorded baseline is one reviewable diff. Never record again in the middle of a refactoring: that swaps the net for whatever the half-changed code returns.

While it stays, an intended behaviour change updates the affected snapshots in the same commit as the change, reviewed like the change itself. A scenario is removed only when a targeted test pins the same input with the same result at the same entry point, so nothing the golden master protects is lost.

**Pest major upgrade.** Pest names snapshot files differently between majors, so after the upgrade every snapshot is missing under its new name. Record them again on code that is otherwise unchanged, in a commit of its own, and check that the diff only renames files: any changed content is a behaviour change of the upgrade and is reviewed as such.

To retire a scenario: read its snapshots and list every fact in them (status, redirect, state, effects, each changed or unchanged row, what the fakes recorded, each shown message or text). Find the targeted tests for the same entry point and the same kind of input, and note which facts they assert. Write the missing facts as explicit assertions into the targeted test (`assertDatabaseHas`, `Notification::assertNothingSent()`, `assertSee()` of the message, `assertJsonPath()`). Then measure: run `--mutate --class={classes behind the entry point} --covered-only` once over the targeted tests alone and once over the golden master group; when every mutation the golden master catches is also caught by the targeted tests, delete the scenario and its snapshot files. Facts from Blade views, routes, and configuration are never mutated, so for them the explicit assertion is the only check.
