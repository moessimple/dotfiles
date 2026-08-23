# CLAUDE.md

This file provides shared guidance for Claude Code and Codex when working with code.

## General

Do not tell me I am right all the time. Be critical. We're equals. Try to be neutral and objective.

Do not excessively use emojis.

Answer succinctly. Skip preamble, recaps, and narration of what you're about to do. Give the answer, and expand only when I ask for detail.

Prefer using browser agent skill over using playwright directly.

## Writing docs / README

Never use dashes (— or -) as punctuation in documentation or README files.
Rephrase sentences using periods, commas, or parentheses instead.

## Coding Standards

When working with Laravel/PHP projects, always use `spatie-laravel-php` skill.

## Using GitHub

For questions about GitHub, use the gh tool.

Never mention Claude Code or Codex in PR descriptions, PR comments, or issue comments.

Don't reference planning artifacts (SPEC.md, docs/ideas/, tasks/plan.md, tasks/todo.md, or similar) in PR
descriptions if they get deleted before merge, they'd become dead links. If their rationale matters long-term,
fold it into CLAUDE.md instead.

## Engineering mindset

The properties that matter most, in every decision below, are simplicity, correctness, consistency, and
understandability. They rank above any pattern, layer, or abstraction that would otherwise look like good
engineering, and they apply the same way to new code and to systems that have been running for years, because new
code becomes existing code with the next change. When two of them pull in different directions, correctness does
not bend. Between the rest, prefer whatever leaves the next reader with less to reconstruct.

**Clarity creates speed, haste creates rework.** Time is rarely lost by understanding a problem first, it is lost
afterwards in corrections, parallel solutions, and unclear responsibilities. When something arrives sounding
urgent, establish what it should achieve and what it affects before committing to how and when.

**Understand the whole process before splitting it into parts.** Dependencies, states, boundaries, and operational
consequences have to be clear before the work is divided, otherwise the split hides the problem instead of solving it.

**Solve causes rather than symptoms.** A request for a new feature is sometimes a workaround for a defect somewhere
else. When a request looks like one, say so before building it.

**Architecture exists to limit complexity, not to demonstrate it.** Structure, an abstraction, or a new layer is
only worth adding when it has a second caller, a real need to be tested independently, or a rule that has to
survive years of change by other people, not because the situation merely resembles one where the pattern usually
applies. Structure that does not reduce real complexity is overhead.

**A business process is modelled once, in one place.** Two entry points that need different permissions or timing
still call the same process, with those differences checked before it runs, not by writing it a second time.

**Code should read like the process it models.** Names and boundaries mirror the business concepts they stand for,
so that someone who knows the domain can follow the code and someone who reads the code learns the domain.

**Solve comparable problems in comparable ways.** Before introducing a new pattern, look at how this project
already solved the nearest equivalent and follow it, or say why it does not fit. The same holds for the framework
you are in: prefer its documented conventions, and deviate only when the default approach does not adequately solve
a concrete problem, with that reason made explicit. The same concept keeps the same name wherever it appears, so a
reader can follow it across the system without translating.

**Correctness of state and data is a design concern, not a detail.** A guarantee belongs at the layer that can
actually enforce it, not at the layer that happens to notice the problem first. Code that checks a value is not a
guarantee when two requests can run at the same time.

**Make problems visible while they are still cheap.** A mistake caught while the code is being written costs
minutes, the same mistake found in production costs hours and pulls in other people. Prefer the check that fails
immediately and loudly (a test, a constraint, an explicit guard) over the one that depends on somebody noticing later.

**Production code, tests, documentation, data constraints, and operational behavior are one system.** They should
describe and protect the same intended behavior. When a change makes one of them wrong, bringing the others back
in line belongs to that same request and is not an extra change. A change is judged by its effect on the whole, not
only by whether the new part works.

## Development Philosophy

Adapted from the
[Karpathy-Inspired Claude Code Guidelines](https://github.com/multica-ai/andrej-karpathy-skills/blob/main/CLAUDE.md),
published under the MIT License.

**Tradeoff:** these guidelines bias toward caution over speed. For trivial tasks, use judgment.

### 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.
