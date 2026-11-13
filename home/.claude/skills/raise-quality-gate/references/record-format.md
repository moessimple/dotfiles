# QUALITY_GATE.md

The record of raising the gate, in the repository root, so that anyone on the team can continue with the next stage and see what was decided. Written in the language of the project's documentation. Update it with every commit of a stage. The baseline of equivalent mutations is not repeated here: it stays in `tests/CHARACTERIZATION.md`.

```md
# Quality gate

Raised towards the gate of PHPStan max with Larastan, 100 % type coverage, Rector's Laravel and prepared sets, and Pint. Every step kept the behaviour, checked by `composer test` and a mutation run over the changed classes.

## Security
Known vulnerabilities `composer audit --locked` reports. Updating a production package changes behaviour, so it is a decision for people, outside this gate.
- `{package}` {installed version} ({production | dev}): {advisory ID and title}, severity {severity}, fixed in {version} | none
- Secret in the history: `{file}` in {commit}, rule {gitleaks rule}; rotate it | none | scan did not run: {why}

## Stages
| Stage | Branch | State |
|---|---|---|
| {1 to 4, or a behaviour-changing rule} | `{branch}` | in progress / in review / merged |

## Values
| Tool | Start | Now | Target |
|---|---|---|---|
| PHPStan | level {n}, {n} baseline entries | level {n}, {n} baseline entries | max, no baseline |
| Type coverage | {percent} | {percent} | 100 % |
| Rector | {sets applied} | {sets applied} | all sets of the gate |
| Pint | {rules left out} | {rules left out} | the gate's rules |
| Architecture presets | {n} ignored | {n} ignored | none ignored, or each one decided |

## Decisions
- {date}, {who}: {what was decided, such as applying `strict_comparison` or accepting a failing audit, and why}

## Open decisions
- {behaviour-changing rule with the places it would change, a departure from the gate, a production update a tool needs, a PHPStan error that only a behaviour change fixes}

## Blockers
- {blocker and cause | none}
```
