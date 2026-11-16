# tests/CHARACTERIZATION.md

The record of the characterization, so that anyone on the team, or a later run, can see what is pinned, continue where a run stopped, and work with the tests. Written in the language of the project's documentation, except for the headings `## Areas` and `## Capabilities`, the column names of their tables, and the status values, which stay in English because other skills read them. Update it after every capability, and commit it together with the tests.

```md
# Characterization

Recorded at {sha} on {date}. The tests pin what the application did at that point; they do not say it is right.

## Security
What has to be closed before the repository is made public, and passed to whoever runs the application now.
- Advisories from `composer audit`: `{package}` {installed version} ({production | dev}), {advisory}, severity {severity}, fixed in {version} | none
- {what happens, in one sentence}: `{test file}`, details under Notable behaviour | none

## Working with these tests
- Run `composer test` after every small step. It fails when coverage drops below {floor} %, the floor reached so far. The floor rises after every secured area and never drops; once every area is secured at 100 %, the gate requires exactly 100 %.
- A failing test means behaviour changed. If the change was not meant to alter behaviour, undo it.
- If the change is intended (a fix, a feature), change the test in the same commit and review that diff like code.
- A test with a `->note()` pinned behaviour that already looked wrong; `vendor/bin/pest --notes` lists them. Changing it on purpose means changing the test and removing the note in the same commit.
- Before committing a refactoring, run `{mutation command for changed classes}`: a surviving mutation not listed under Equivalent mutations means the tests no longer check that code.

## Setup
- Pest {version}, pest-plugin-laravel {version}, PHPUnit {old} → {new}
- Database engine: {production engine `{name}_testing` | SQLite, production uses {engine}: {why}}
- Changes besides tests: {phpunit.xml entries, test-only APP_KEY, suite directories, Composer scripts}

## Baseline
- Existing tests before setup: {n passed, n failed}, under Pest: {n passed, n failed}
- Coverage of the existing tests: {percent}, the first floor of `composer test`
- Steps of the project's test command that were already red: {step: cause | none}
- Repaired existing tests: {test: missing setup that was added}
- Failing existing tests: {test: cause}

## Areas
| Area | Paths | Risk | Status | Coverage | Mutations |
|---|---|---|---|---|---|
| {area, as a user would name it} | `{path}`, ... | high / medium / low | open / in progress / secured | {percent of the area's lines} | {score}, {n} equivalent |

## Capabilities
| Area | Capability | Risk | Status | Tests |
|---|---|---|---|---|
| {area} | {capability, as a user would name it} | high / medium / low | open / in progress / secured | `{test file}` |

## Coverage
- Floor of `composer test`: {percent}, the total after the last secured area
- Not covered by this run: {JavaScript frontend under `{path}` | none}
- Excluded files: `{file}`: {reason}
- Uncovered lines: `{file}:{lines}`: {reason}

## Equivalent mutations
The baseline later work checks against: a surviving mutation not listed here is a gap in the tests. An entry is removed when the code it describes changes.

- Score: {percent}, {n} survivors
- `{file}` {mutator}, `{code before}` → `{code after}`, risk {high | medium | low}: {why no actor can observe the difference}. Confirmed: {name | open}

## Notable behaviour
Each entry is a test with a `->note()`. Security first.

### {Security | Notable}: {what happens, in one sentence}
- Test: `{file}` ({test name})
- Why it looks wrong: {one or two sentences}
- What the repository says: {linked from the interface or not; commit that introduced it and its message; stored data that relies on it | nothing found}
- Decision: {open | intended (note removed) | bug, issue {number}}

## Not testable without changing code
- `{file}`: {call that reaches outside}, untested paths: {...}

## Open
- {blocker and cause, or a question for a person, such as an unconfirmed equivalent mutation of a high-risk capability | none}
```

Equivalent mutations name the file, never the line or Pest's ID: Pest hashes the whole mutated file into the ID, and lines move with any edit, so later runs match an entry by file, mutator, and the code before and after.

An area is `secured` when every line of its files is covered or listed under Coverage with its reason, every surviving mutation of its classes is caught by a test or listed under Equivalent mutations, and the self-check shows no hit without an explanation in the report. Until then it is `in progress`.
