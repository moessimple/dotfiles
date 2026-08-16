---
paths:
  - "**/*.bats"
  - "**/{test,tests}/**/*.bash"
---

## Bats correctness

Bats tests are shell programs. A check is an assertion only when its failure necessarily fails the test.

1. Invoke a command directly when only success matters. When `run` is needed to capture output or status, declare
   the expected exit status with `run -N` or `run !`; if the project's Bats version does not support that syntax,
   assert `$status` immediately after `run`.

2. Do not rely on bare `! command`, `[[ ... ]]`, or `(( ... ))` as intermediate assertions. Use `[ ... ]`, `run !`,
   a project-provided assertion helper, or an explicit `|| false` so a failed assertion cannot be ignored by Bash.

3. Do not pipe directly after `run`. Capture the complete pipeline with `bats_pipe` or test a wrapper function that
   contains the pipeline.

4. Keep each test's mutable state under `$BATS_TEST_TMPDIR`. Tests must not depend on execution order and must
   remain safe when run in parallel.

5. Keep top-level test-file code free of side effects because Bats evaluates the file more than once. Define or
   load helpers there, but source production scripts in `setup` or in the test that uses them.

6. If a test starts a background process, close inherited Bats file descriptors and always stop and wait for the
   process during cleanup.

7. Use only features supported by the project's declared Bats version. When relying on a newer feature, pin or
   raise that version and declare it with `bats_require_minimum_version`.

8. Keep Bats test bodies readable as behavior specifications, including for readers who are not fluent in shell
   scripting. A reader should be able to understand the scenario, action, and expected outcome from the test body
   without mentally interpreting shell expressions or opening support helpers. Move reusable shell mechanics for
   fixtures, test doubles, and assertions into support helpers with names that state their purpose. Keep scenario
   specific values, actions, and expected outcomes visible in the test so helpers do not hide the behavior being
   protected.

9. Do not use fixed sleeps to synchronize tests. Wait for an observable condition with a bounded timeout instead.
