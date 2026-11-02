# Test style

Characterization tests are the documentation of what the application does. A reader who opens a test file should learn the behaviour of that part of the application without reading the code: what it accepts, what it decides, what it changes, and what the actor sees.

## Contents

- Consistency first
- What to test
- Layers
- Tests per kind of behaviour
- Names and grouping
- Shape of a test
- Assertions
- Fakes and determinism
- Code that no request reaches
- Behaviour that looks unintended
- Before a test counts

## Consistency first

Read the existing tests before writing one. A pattern the project repeats is its convention and wins over these rules, with one exception: new tests never check structure instead of behaviour (see Layers), even where existing tests do. An existing test that follows a project convention is not wrong because it differs from these rules. New tests are written with Pest's functions even where the existing tests are PHPUnit classes; those stay as they are.

## What to test

- Observable behaviour: what an actor gets back (status, page content, JSON, redirect, message) and what changes (records, files, dispatched jobs, mail, notifications). A test must still pass after a refactoring that keeps the behaviour.
- Every decision in the code under test: each branch, validation, calculation, and authorization check, and each failure that matters. Decisions in templates count too (`@if`, `@foreach`, formatting, links): coverage measures PHP code only, so the coverage gate does not show them, and completeness is judged by decisions, not by the coverage number.
- What the project configures with the framework, such as a relationship with a constraint, a cast, a cascade, or a scope. Not the framework itself.

## Layers

**Tests per entry point.** Every entry point gets a test file at the mirrored path in `tests/Feature`: `app/Http/Controllers/Admin/ProductController.php` gets `tests/Feature/Http/Controllers/Admin/ProductControllerTest.php`, and the same holds for Livewire and Volt components, console commands, jobs, listeners, mail, and notifications. A closure route has no class; name its file after the route file, such as `tests/Feature/Routes/WebRoutesTest.php`, and broadcast channels `tests/Feature/Routes/ChannelsTest.php`. These tests run the real application behind the entry point: routing, middleware, validation, the classes the code calls, persistence, response. They are the net for the refactoring that follows: a class can be split, renamed, or inlined, and they stay green.

**Unit tests only where no entry point reaches.** A class gets its own test file at the mirrored path in `tests/Unit` only when one of its decisions cannot be reached through an entry point with reasonable setup (for example a calculation with many input combinations, best covered by a dataset), or when nothing reaches it at all (see Code that no request reaches). Such a test may boot the framework and use the database, factories, and fakes.

**Structure is not behaviour.** Which form request, middleware, action, or service an entry point uses is the structure the refactoring is meant to change. Test what they do through the entry point, never that they are used: no reflection checks of parameter types, no mocked action with an expected call.

**Mocks** replace only what leaves the process (external services, subprocesses, the network). Classes of the application always run for real, also when they have a test of their own. A partial mock that stubs one boundary method while the rest runs for real gets a comment saying why.

## Tests per kind of behaviour

- **Validation** (form request or inline): through requests at the entry point. Per field, a dataset of the inputs its rules reject, asserting the message the user receives (`assertSessionHasErrors(['name' => 'The name field is required.'])`, `assertJsonValidationErrors(['name' => '...'])`, or `assertHasErrors(['name' => '...'])` for Livewire), and one request with valid input. `authorize()` through a request from an actor it refuses. Never compare the array `rules()` returns: it misses validation that happens elsewhere (`prepareForValidation()`, a data object's own validation) and fails when rules are rewritten with the same effect.
- **Action or service:** the result, the database, and every side effect, for the main path and each failure, through the entry point that calls it; directly only under the unit rule above.
- **Middleware:** through a route that uses it, letting through and refusing. Register a route only for the test when no route uses the middleware or a branch cannot be reached through a real one.
- **Model:** casts, accessors and mutators, relationships with constraints, scopes, through the entry points that show them; directly only what no entry point shows.
- **Enum:** the backed values with `toBe()` where they are stored or sent, and every method it adds that an entry point uses.
- **API resource:** through the endpoint, the exact JSON with `assertExactJson()` or `assertJsonPath()`, and conditional fields with and without their relation.
- **Mail and notifications:** the recipients, the subject, and the rendered content a recipient reads.
- **Data object:** through the entry points that build it, including each missing required field.

## Names and grouping

- Use `it()` with a verb phrase that states the result and the condition that causes it: `it('rejects a product without a name')`, `it('returns 404 for a product that does not exist')`. Name the behaviour, never the method under test, and do not write Given, When, or Then.
- Never use `describe()`. The file groups the tests of one entry point, and every test name stands on its own: it names the action where the file covers several, such as `it('returns 404 when updating a product that does not exist')` next to `it('returns 404 when deleting a product that does not exist')`.
- Use a dataset when setup, action, and assertions are the same and only the input differs, and give every case a name that states the difference. If cases need different setup or assertions, write separate tests: a branch inside a test is two tests.

## Shape of a test

Every test has its parts in this order, each separated by one blank line: fakes and mocks, the setup, exactly one action, and the assertions.

```php
it('creates a product with a slug made from its name', function () {
    $response = $this->post(route('admin.products.store'), ['name' => 'Desk Lamp']);

    $response->assertRedirect(route('admin.products.index'));
    $response->assertSessionHas('success', 'Product created.');
    $this->assertDatabaseHas('products', ['name' => 'Desk Lamp', 'slug' => 'desk-lamp']);
});
```

- The action is one statement and its result goes into a variable (`$response`, `$result`). Assertions follow on that variable, not chained onto the request.
- Every value the test asserts appears in the test itself, in the setup or as a literal in the assertion. A helper may fill in values the test does not care about, never values it asserts.
- Each test creates its own records, with factory states and `for()` where they give the data meaning. Create only the records the behaviour or an assertion needs.
- `beforeEach()` holds configuration and fakes that every test in the file needs, such as `Storage::fake('public')` in a file whose tests all upload. It never creates records. A fake only some tests need stays in those tests.
- A comment appears only where a choice in the test is not obvious from the code, such as a partial mock or a direct call to unreachable code.

## Assertions

- Use the assertion made for the subject, so a failure names the broken contract: named response assertions (`assertOk()`, `assertNotFound()`, `assertRedirect()`), session assertions, database assertions (`assertDatabaseHas()`, `assertModelExists()`, `assertModelMissing()`), fake assertions, and `expect()` for plain values. Compare with exact values (`toBe()`), and with `toEqual()` only for structures that hold objects.
- Keep `assertOk()` next to `assertSee()`: an error page can contain the same text.
- Assert what the actor sees, not what the controller hands to the view: `assertSee()` and `assertSeeText()` on the rendered page rather than `assertViewHas()`. Choose values that occur nowhere else on the page.
- Assert the complete result of a write: the response, the database, and every side effect. On a failure path, assert that nothing changed.
- Write expected values as known literals. Never compute them with the same logic as the code under test.
- When the current behaviour is an exception, assert which one with `Exceptions::fake()` and `Exceptions::assertReported(...)` next to the response, so the test documents the cause and not only a status 500.

## Fakes and determinism

- Use the framework's fakes for storage, mail, notifications, events, queues, outbound HTTP, time, and sleep, and the real implementation for everything else.
- The baseline in `tests/Pest.php` prevents stray requests and processes, restores random strings and UUIDs, fakes sleep, and freezes time for every test. Every other fake belongs in the test or, when every test of a file needs it, in that file's `beforeEach()`.
- When `Event::fake()` or `Queue::fake()` is used, name the classes, and create the factory records before calling it.

## Code that no request reaches

Code without an entry point still has behaviour. Test it directly through its public interface, and state in a comment above the test why it is called directly:

```php
// No route uses ReportController::archive, so no request can reach it.
it('returns the report archive page from archive', function () {
    $view = (new ReportController)->archive();

    expect($view->name())->toBe('reports.archive');
});
```

## Behaviour that looks unintended

Pin it like any other behaviour, name the test plainly after it, and add one note that says what looks wrong and why. `Security:` replaces `Notable:` when it concerns access, authentication, or exposed data:

```php
it('lets a visitor who is not logged in open the admin dashboard', function () {
    $response = $this->get(route('admin.dashboard'));

    $response->assertOk();
    $response->assertSeeText('Dashboard');
})->note('Security: no route of the admin area requires a login.');
```

The note is what tells a developer, when this test turns red, that the behaviour was questionable before the change: nobody has to decide today whether it was intended.

## Before a test counts

Ask for every test: would it still pass after a refactoring that keeps the behaviour, could the application be broken for its user while this test stays green, and which actor needs the asserted outcome? A test that fails any of the three is rewritten or removed.
