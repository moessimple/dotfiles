# Test style

Characterization tests document what the application does. A reader who opens a test file learns what that entry point accepts, decides, changes, and shows, without reading the code.

Read the existing tests first. A pattern the project repeats is its convention and wins over these rules, with one exception: new tests check behaviour, never structure. New tests use Pest's functions even where existing tests are PHPUnit classes; those stay as they are.

## Layers

- **One file per entry point** at the mirrored path in `tests/Feature`: `app/Http/Controllers/Admin/ProductController.php` gets `tests/Feature/Http/Controllers/Admin/ProductControllerTest.php`; the same for Livewire and Volt components, commands, jobs, listeners, mail, and notifications. Closure routes get a file named after their route file (`tests/Feature/Routes/WebRoutesTest.php`). These tests run the real application: routing, middleware, validation, persistence, response.
- **Unit tests only where no entry point reaches**, or where a decision has so many input combinations that a dataset on the class is the reasonable way. They may boot the framework.
- **Structure is not behaviour.** Which form request, action, or service handles a request is what the later refactoring will change. Never assert that a class is used: no reflection checks, no mocked internal class with an expected call.
- **Mocks** only for what leaves the process (external services, subprocesses, the network). A partial mock gets a comment saying why.

## What to assert

- What an actor gets back (status, rendered text, JSON, redirect, message) and what changes (rows, files, dispatched jobs, mail, notifications). On a write, the complete result: response, database, and every side effect. On a failure path, that nothing changed.
- Every decision: each branch, validation rule, calculation, and authorization check. Decisions in Blade templates (`@if`, `@foreach`, formatting) count too: coverage measures PHP only and mutation never touches templates, so only an explicit `assertSee()` pins them.
- **Validation** through requests at the entry point, per field a dataset of rejected inputs asserting the message the user receives. Never compare the array `rules()` returns: it misses validation elsewhere and breaks when rules are rewritten with the same effect.
- **An exception** as current behaviour: assert which one with `Exceptions::fake()` and `Exceptions::assertReported()`, next to the response.
- Rendered output with `assertSee()`/`assertSeeText()`, not `assertViewHas()`, and always next to `assertOk()`: an error page can contain the same text.
- Expected values as literals in the test. Never compute them with the logic under test. A helper may fill in values the test does not care about, never values it asserts.

## Shape

```php
it('creates a product with a slug made from its name', function () {
    $response = $this->post(route('admin.products.store'), ['name' => 'Desk Lamp']);

    $response->assertRedirect(route('admin.products.index'));
    $this->assertDatabaseHas('products', ['name' => 'Desk Lamp', 'slug' => 'desk-lamp']);
});
```

- `it()` with a phrase that states the result and its condition. Name the behaviour, never the method. No `describe()`.
- Fakes, setup, exactly one action, assertions, separated by blank lines.
- Each test creates its own records. `beforeEach()` holds only fakes every test in the file needs, never records.
- `Event::fake()` and `Queue::fake()` name the classes they fake, and come after the factory records, the one exception to fakes first: a global fake also silences model events and observers, and the test would pin a state production never reaches.
- A dataset only where setup, action, and assertions are the same and only the input differs, each case named after the difference. A branch inside a test is two tests.

## Code that no request reaches

Test it directly through its public interface, with a comment saying why:

```php
// No route uses ReportController::archive, so no request can reach it.
it('returns the report archive page from archive', function () {
    $view = (new ReportController)->archive();

    expect($view->name())->toBe('reports.archive');
});
```

## Behaviour that looks unintended

Pin it, name the test plainly after it, and add one note:

```php
it('lets a visitor who is not logged in open the admin dashboard', function () {
    $response = $this->get(route('admin.dashboard'));

    $response->assertOk();
    $response->assertSeeText('Dashboard');
})->note('Security: no route of the admin area requires a login.');
```

When this test turns red later, the note tells the developer the behaviour was questionable before the change.

## Acceptance tests

An acceptance test pins a confirmed rule, not the current code. Everything above applies, except where this section says otherwise.

- **Place and name:** one file per area, `tests/Feature/{Area}RulesTest.php`, that starts with `pest()->group('acceptance');`, so `pest --group=acceptance` runs them and the self-check knows them. Every test name starts with the rule's ID: `it('RULE-012: deducts 5 % from an order of 500.00', ...)`.
- **Given, When, Then** of the rule become the setup, the one action at an entry point, and the assertions.
- **Expected values** are the rule's own values, written as literals. Never take one from a run against the code: that would pin the current behaviour, which is what a characterization test already does.
- **Code that does not meet the rule:** do not adapt the test, and do not leave it red. Record under Notable behaviour the rule's ID, the confirmed value, and the current value, marked intended ≠ current. Fixing it is later development work, with a test that fails first.
- **Lock:** a new file goes into `tests/acceptance.lock.json` with its SHA-256 once its tests pass, so `tests/Unit/AcceptanceGuardTest.php` fails on any later edit. A committed file is never edited, not even to add a test: new rules of an area that already has one go into a new file, `tests/Feature/{Area}Rules{n}Test.php`, numbered from 2.
- **Existing acceptance tests** are changed or deleted only when the invocation asks for it by the rule's ID. Then the file and its lock entry change in the same diff, and the report names the rule ID.
