# Definition of Done

- Pest is set up after the reference, and the existing tests give the same result as before
- Every precondition was checked in order, and the run stopped at the first failure
- Every capability derived from the entry points has a risk and is `secured`, or the report says why not
- The suite passes apart from the existing failures from the baseline, and every test file also passes on its own
- `pest --coverage --exactly=100.0` passes, or every missing line is in the report with its reason, and `composer test` runs that gate
- The self-check found no hit, or every hit is fixed or in the report, and every surviving mutation is caught by a sharpened test or recorded as equivalent with its reason
- `git status --porcelain` shows only files the table allows, and the diff in application code is empty
- The golden master is recorded and passes, CI runs it or the report says why not, and the tests ran on the production engine or the report says why not
- Every test that pins behaviour that looks unintended carries a `Notable:` or `Security:` note, and `tests/CHARACTERIZATION.md` lists it with its evidence, every `Security:` finding and audit advisory also in its Security section at the top
- For a package, the suite also ran with the lowest versions, and every difference is in the report
- `tests/CHARACTERIZATION.md` holds the setup, baseline, capabilities with their status, coverage, golden master, equivalent mutations, findings, and open points, so someone else can continue the run or build on its result
- The report states the blocker and its cause, or the result of the characterization
- The handover is in the report and in `tests/GoldenMaster/README.md`
