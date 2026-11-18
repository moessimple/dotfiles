---
paths:
  - "**/{test,tests,spec,specs,__tests__}/**/*"
  - "**/*.{test,spec}.{js,jsx,ts,tsx,mjs,cjs,vue}"
  - "**/*Test.php"
  - "**/Pest.php"
  - "**/test_*.py"
  - "**/*_test.{py,go,rb,rs}"
  - "**/*_spec.rb"
  - "**/*{Test,Tests,IT}.{java,kt,cs,swift}"
  - "**/*.bats"
---

## Test design

Tests protect observable contracts, not the current shape of the implementation. An observable contract is an
outcome that matters to a user, an API consumer, a calling component, an operator, or an explicitly documented
technical boundary.

1. Begin with the behavior or guarantee being protected and identify which part of the system owns it. Name the
   test after the outcome, not the method or class under test. Distinguish user behavior from a technical contract.

2. Let each test layer prove its own responsibility. Use the lowest layer that can prove the contract without
   bypassing a relevant integration boundary. Do not repeat the same proof at every layer merely for coverage.

3. Keep one behavior per test. Make arrange, act, and assert visibly distinct. Keep setup deterministic and make
   every value that matters to the scenario explicit.

4. Assert public outputs and observable effects. These include responses, rendered content, persisted state,
   emitted events, external calls at a system boundary, and errors visible to a caller. Do not assert private
   methods, private state, incidental call order, or internal collaborators unless the delegation itself is an
   explicitly declared architectural or operational contract.

5. Do not infer that separately passing tests prove that the assembled system works. Protect each critical journey
   at a public entry point whenever correctness depends on routing, wiring, serialization, persistence, or several
   components working together.

6. Prefer real owned objects and fast, deterministic owned collaborators. Use factories or builders to provide
   valid defaults and express meaningful scenarios, but keep one off values local and visible. Do not let test
   helpers hide the behavior being arranged or asserted.

7. Use test doubles when a boundary is slow, nondeterministic, destructive, or externally controlled, or when the
   collaborator already has its own dedicated test and only the caller's own use of it needs proving in isolation.
   Guard uncontrolled network, process, filesystem, time, queue, and similar side effects so an unexpected call
   fails loudly. Do not replace the integration that the test is meant to prove. Exercise every important fake or
   mock seam against the real contract at an appropriate higher layer.

8. Exercise an interface through its public language and realistic interactions available to its consumer. For a
   user interface, this means accessible roles, labels, visible text, and user events. Avoid private APIs, internal
   structure, incidental selectors, and snapshots as the sole proof of correctness.

9. Keep slow end to end tests for behavior that depends on production wiring or the real runtime environment.
   Protect a small number of critical journeys across the assembled system instead of repeating logic already
   covered by faster tests.

10. Establish the happy path for a behavior, then cover meaningful boundaries and failures, including invalid
    input, unavailable dependencies, conflicting writes, authorization, and concurrency when they can change an
    observable outcome. Do not add cases merely to execute branches or increase coverage.

11. Reproduce regressions through the narrowest public boundary that still exposes the real defect. Before applying
    the fix, verify that the regression test fails for the expected reason. After applying the fix, verify that the
    same test passes. When changing unclear existing behavior, characterize it first, then decide explicitly whether
    the implementation or the expected contract must change.

12. A behavior preserving refactor should normally not require test changes. If it does, first check whether the
    test depends on an implementation detail.

13. Architecture, orchestration, performance, security, serialization, and interoperability requirements may be
    technical contracts. State and label them explicitly, assert only the constraint that matters, and do not count
    them as end user behavior coverage.

14. Treat coverage metrics as evidence of executed code, not proof of complete behavior. Identify critical
    behaviors explicitly and ensure each is protected at an appropriate layer.

15. Run the smallest relevant test set first for fast feedback, then run the project's required quality gate before
    considering the change complete. Report only checks that actually ran.

16. Keep test logic simpler than the production logic it verifies. Avoid conditionals, loops, complex calculations,
    and dynamically derived expected values when explicit examples or clearly named datasets can express the
    behavior more directly. Do not reproduce the production algorithm in the test to calculate the expected result.

17. Tests must be deterministic, order-independent, and safe to run repeatedly or in parallel where the project
    supports it. Keep mutable state test-local and clean up temporary or process-wide state even when the test throws.
    Treat a flaky test as a defect. Do not rerun a failing test until it happens to pass; identify and remove the
    source of nondeterminism instead.

18. Write expected values as literals derived from the requirement, next to the inputs that produce them. Never copy
    the output the code currently produces into an assertion: a pasted actual value turns a bug into the
    specification. The only exception is a characterization test that records current behavior before a change and
    says so in its name.

19. Treat a failing assertion as evidence. Do not delete, weaken, skip, or rewrite it to get the suite green until it
    is clear whether the code or the expectation is wrong. Change an existing expectation only because a requirement
    changed, and name that requirement in the commit message.

20. See every new or changed test fail for the expected reason before relying on it. For a test of existing
    behavior, temporarily invert the condition it protects in the production code, run the test, and restore the
    production code. A test that stays green under that change protects nothing.

21. Make a failure explain itself: it shows the expected value, the actual value, and the relevant inputs. Assert on
    the value itself with the most precise assertion available, not on a boolean or a count derived from it.

22. Do not mock types you do not own. Wrap a third-party API in a thin adapter the project owns, replace the adapter
    in unit tests, and test the adapter against the real dependency. Take the format a fake reproduces from the real
    tool's output or documentation, never from memory. Verify only the interactions and arguments that form the
    contract, not every call.

23. Never regenerate snapshots wholesale to get a suite green. Read the diff of each failing snapshot, fix the code
    on a regression, and regenerate only the snapshot whose change is intended. Keep snapshots small and
    deterministic by masking timestamps, IDs, and tokens, and assert the values that matter explicitly as well.

24. Check the flags and behavior of a test tool or framework in the installed version's documentation, `--help`, or
    source before a test or fake depends on them. When a script rewrites many tests at once, compare each changed
    file with the previous version after filtering out the intended change, and run the full suite: a split line or
    a moved statement can leave a test green while it checks something else.

Before keeping a test, answer all three questions:

1. Would it still pass after a behavior preserving refactor?
2. Could the application be broken for its user or caller while this test remains green because a relevant
   integration was mocked or bypassed?
3. Which user, caller, operator, or explicitly declared technical contract needs the asserted outcome, and is this
   the layer that owns that guarantee?
