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

3. Do not pipe directly after `run`. Capture the complete pipeline with `bats_pipe`. Test a wrapper function that
   contains a pipeline only when that wrapper is itself part of the behavior under test and deliberately defines
   the pipeline's exit-status semantics.

4. Keep test-owned mutable state under `$BATS_TEST_TMPDIR`. Use file- or suite-level temporary directories only for
   state that is deliberately shared between tests. Tests must not depend on execution order and must remain safe
   when run in parallel.

5. Keep top-level test-file code free of side effects because Bats evaluates the file more than once. Top-level
   helper definitions and side-effect-free helper loads are acceptable; source production scripts in `setup` or
   in the test that uses them.

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

9. Remember that `run` executes its command in a subshell. Call a shell function directly when the behavior under
   test is a mutation of the current shell state.

10. `run` combines stdout and stderr by default. When their distinction is part of the observable contract, use
    `run --separate-stderr` and assert the streams separately.

11. Do not depend accidentally on the directory from which Bats was invoked. Resolve test and project paths from
    Bats-provided path variables or explicit test setup unless the working directory itself is part of the contract.

12. Put cleanup that must happen after a failed test in the appropriate `teardown*` hook. Handle cleanup failures
    explicitly because errexit is disabled inside teardown hooks.
