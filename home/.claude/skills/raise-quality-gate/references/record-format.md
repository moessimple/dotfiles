# QUALITY_GATE.md

The record of raising the gate, in the repository root, so that anyone on the team can continue with the next run and see what was decided. Written in the language of the project's documentation, except for the headings `## Runs`, `## Progress`, `### Areas`, `### Values`, and `## Deferred types` and the state values, which stay in English because the skill reads them. Update it with every commit of a run. The baseline of equivalent mutations is not repeated here: it stays in `tests/CHARACTERIZATION.md`.

```md
# Quality gate

Raised towards the gate of PHPStan max with Larastan, 100 % type coverage, Rector's Laravel and prepared sets, and Pint. Every step kept the behaviour, checked by `composer test` and a mutation run over the changed classes.

## Security
Known vulnerabilities `composer audit --locked` reports. Updating a production package changes behaviour, so it is a decision for people, outside this gate.
- `{package}` {installed version} ({production | dev}): {advisory ID and title}, severity {severity}, fixed in {version} | none
- Secret in the history: `{file}` in {commit}, rule {gitleaks rule}; rotate it | none | scan did not run: {why}

## Runs
| Run | Branch | State |
|---|---|---|
| tools / {area} / {planned change} / tests / {behaviour-changing rule} | `{branch}` | in progress / in review / merged |

## Progress
Updated by every run, so the way to the gate is visible at a glance.

### Areas
| Area | Capabilities | Modernized files | State |
|---|---|---|---|
| {area, as in tests/CHARACTERIZATION.md} | {secured}/{all}, from its `Capabilities` column | {files taken out of the skip list}/{the area's PHP files} | open / improved |

An area is `improved` once none of its files is left in `rector-skip.php`, whether `area` runs or planned changes took them out.

### Values
| Value | Start | Now | Target |
|---|---|---|---|
| Coverage floor of `composer test` | {percent} | {percent} | exactly 100 % |
| PHPStan baseline errors (level max) | {n} | {n} | 0, no baseline |
| Rector skipped files | {n} | {n} | 0 |
| Type coverage | {percent} | {percent} | 100 % |
| Pint | {rules deferred} | {rules deferred} | the gate's rules |
| Architecture presets | {n} ignored | {n} ignored | none ignored, or each one decided |

## Deferred
- `ordered_traits`, `ordered_class_elements`: turned on in the `tests` run, because only full coverage reliably shows their effect.

## Deferred types
Public and protected signatures that got their type only as PHPDoc, because safety rule 2 of the gate keeps them unchanged until every area is secured. The `tests` run gives each its native type.
- `{file}` `{Class::method}`, {parameter or return}: `{type}`, Rector rule skipped: `{rule}` | none

## Decisions
- {date}, {who}: {what was decided, such as applying `strict_comparison`, turning on `codingStyle`, or accepting a failing audit, and why}

## Open decisions
- {behaviour-changing rule with the places it would change, a departure from the gate, a production update a tool needs, a PHPStan error that only a behaviour change fixes, code outside every area that stays skipped}

## Blockers
- {blocker and cause | none}
```
