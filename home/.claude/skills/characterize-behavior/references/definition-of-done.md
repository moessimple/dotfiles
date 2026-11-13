# Definition of Done

- Pest is set up after the reference, and the existing tests give the same result as before
- Every precondition was checked in order, and the run stopped at the first failure
- Every capability from the inventory has a risk and is `secured`, or the report says why not
- The suite passes apart from the existing failures from the baseline, and every new test file also passes on its own
- `pest --coverage --exactly=100.0` passes, or every missing line is in the report with its reason, and `composer test` runs that gate
- Every surviving mutation is caught by a test or recorded as equivalent with its reason
- The self-check found no hit, or every hit is fixed or in the report, and the diff in application code is empty
- Every test that pins behaviour that looks unintended carries a `Notable:` or `Security:` note and is listed in `tests/CHARACTERIZATION.md`, every `Security:` finding and audit advisory also in its Security section at the top
- For a package, the suite also ran with the lowest versions, and every difference is in the report
- `tests/CHARACTERIZATION.md` is complete enough for someone else to continue the run or work with the tests
