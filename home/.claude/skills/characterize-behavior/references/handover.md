# Handover

The developers who inherit the tests did not see the run. They need to know, in plain words, what each part is for, what to do when it fails, and where it is meant to go. Give this in two places:

- the final report, in the user's language;
- `tests/GoldenMaster/README.md`, in the language of the project's documentation, so it stays next to the snapshots.

Keep it short, concrete, and free of jargon. Name the project's own commands and paths. Template:

```markdown
# What these tests are for

{The application had no reliable tests. | The existing tests left behaviour open.} These tests record
what it does **today**, so that a later change that alters its behaviour by accident is noticed before it
reaches production. They do not say the behaviour is right. Nobody may know any more what was intended, so what the application does now counts
as what it should do, until someone decides otherwise.

## The parts

- **Targeted tests** (`tests/Feature`, …): each checks one behaviour at the place a user or another system
  reaches the application, such as "a full wishlist rejects another product". They stay for good and change
  only when that behaviour is changed on purpose.
- **Notes on tests**: a test with `->note('Notable: …')` or `->note('Security: …')` pins behaviour that already
  looked wrong when it was recorded. `vendor/bin/pest --notes` lists them; `tests/CHARACTERIZATION.md` holds
  each with what the repository says about it.
- **Golden master** (`tests/GoldenMaster`, snapshots in `tests/.pest/snapshots/GoldenMaster`): for many
  inputs, including odd ones, it records everything a user or client can observe: the response, the text on
  the page, the rows in the database, the mails and jobs. It catches what nobody thought to check. It runs
  with `{golden master command}`{, and in CI | ; CI does not run it because …}.
- **Coverage gate**: `{coverage command}` fails if any line of the application is no longer run by a test.

## When a test fails

1. Run `{test command}` after every small step.
2. A failing targeted test or golden master snapshot means behaviour changed. Look at the diff.
3. The test has no note and the change was not meant to alter behaviour: undo the change.
4. The test has a note: the behaviour was already questionable. If you are changing it on purpose, change the
   test and remove the note in the same commit, and say so in the pull request. `Security:` notes go to
   whoever runs the application first, and are closed before the repository is made public.
5. Intended (a bug fix, a new feature): update the test or snapshot in the same commit as the change,
   and review that diff like code. Never run `--update-snapshots` without reading what it changes,
   and never during a refactoring.

## Where this is going

- Refactor in small steps with the tests green, and check the classes a change touches with
  `{mutation command for changed classes}`: a surviving mutation there that `tests/CHARACTERIZATION.md`
  does not list as equivalent means the tests no longer check that code.
- When you pull logic out into new classes, give them tests in the project's style; the targeted tests here
  keep checking that the whole still behaves the same.
- A golden master scenario can go once a targeted test checks every fact its snapshot holds: check with
  `{mutation command}` that nothing is lost, then delete the scenario and its snapshot files.
- Decide a note when you know more: fix the behaviour (and change its test on purpose), or remove the note
  because it is intended.
```
