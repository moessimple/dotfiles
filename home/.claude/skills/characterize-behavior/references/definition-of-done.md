# Definition of Done

`setup`:

- Pest is set up after the reference, and the existing tests give the same result as before
- Every precondition was checked in order, and the run stopped at the first failure
- Every entry point belongs to an area with its paths, a risk, and the status `open`
- `composer test` runs the coverage gate with the coverage of the existing tests as its floor
- `tests/Unit/AcceptanceGuardTest.php` and `tests/acceptance.lock.json` exist, and the guard passes
- For a package, the suite also ran with the lowest versions, and every difference is in the report

`area`, for the area of the run:

- Every capability of the area has a risk and is `secured`, or the report says why not
- The suite passes apart from the existing failures from the baseline, and every new test file also passes on its own
- Every line of the area's files is covered, or listed in the record with its reason, and the floor of `composer test` is raised to the new total
- Every surviving mutation of the area's classes is caught by a test or recorded as equivalent with its reason
- Every confirmed rule the area's entry points reach has an acceptance test that passed in the JUnit report, or an intended ≠ current entry under Notable behaviour; no committed acceptance test changed without a request for its rule ID
- The self-check found no hit, or every hit is fixed or in the report, and the diff in application code is empty
- Every test that pins behaviour that looks unintended carries a `Notable:` or `Security:` note and is listed in `tests/CHARACTERIZATION.md`, every `Security:` finding and audit advisory also in its Security section at the top
- Not secured names everything of the area the test environment cannot check: calls past the framework, locks and races, behaviour that needs a real commit, and queued jobs
- The area is `secured` as the record defines it, or `in progress` with its reason under Open

A planned change:

- The report names the touched classes and capabilities at the top, or the run stopped and asked for paths
- Every touched capability is `secured`, every line of the touched classes is covered or listed with its reason, and every surviving mutation of those classes is caught or recorded as equivalent
- Every confirmed rule those capabilities reach has a passed acceptance test or an intended ≠ current entry under Notable behaviour
- The area's `Capabilities` count is current, and an area whose last capability the run secured went through the closing steps of `area`
- The self-check found no hit, or every hit is fixed or in the report, and the diff in application code is empty

Every mode:

- Every new test passed three runs in a row and covers a line or catches a mutation no other test did, apart from acceptance and guard tests; every deleted flaky test is under Open
- `tests/CHARACTERIZATION.md` is complete enough for someone else to continue the run or work with the tests
