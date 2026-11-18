---
paths:
  - "tests/**"
---

## Test conventions

Tests assert observable files, Git state, output, exit status, and public command contracts. Do not assert source
spelling, private helper names, arbitrary step ordering, or prose formulations. Static checks are appropriate for
declarative configuration and shared document formats consumed by other tools or skills. At external boundaries
that cannot safely run in tests, check command arguments and failure handling; use real tools with isolated data
when practical. `tests/bin/macos-defaults.bats` records privileged calls without executing them and confines real
PlistBuddy writes to its fixture HOME. These tests do not prove that macOS accepts every declared preference or
that a fresh machine can install every external package.

Read tests as behavior documentation. Each `@test` name identifies the command or process, the relevant condition,
and the expected outcome. A reader must be able to understand the preparation, action, and expectations without
reading the production implementation or tracing fixture internals. Arrange the scenario-specific state in the
test; use `setup` for a clearly visible shared baseline and helpers for mechanical fixture construction. Helpers
must not hide the values or conditions that explain the scenario. Assertions state the expected values and effects
explicitly. A call count alone does not prove which database was migrated or which file was imported.

Every test body starts with a section comment and marks its sections with `# Arrange`, `# Act`, and `# Assert`,
omitting a section that has no code (a static check over repository files has only `# Assert`). A marker may add a
short description after a colon, such as `# Arrange: one CPU and a separate PHPUnit database.` A lifecycle test
repeats `# Act:` and `# Assert:` for each transition and names the transition in the description. Markers stay at
the test's top level, never inside a loop: run several cases in one `# Act` section and assert the collected result,
or give each case its own test.

Give distinct conditions and failure modes separately named tests. When a test covers a lifecycle, make each state
transition and its expectations clear. Put single-command scenarios in that command's test file and source-only
checks in `tests/setup/sourcing.bats`. Keep cross-component scenarios together with the behavior they document,
such as the edit-to-stop lifecycle or the machine profile shared by the setup entry points.

Before finishing test changes, read the changed scenarios as documentation. Verify that each name matches the
actual preparation and assertions, that the important conditions and expected results are explicit, and that the
test is located with the behavior it protects. Passing tests alone do not satisfy this review.
