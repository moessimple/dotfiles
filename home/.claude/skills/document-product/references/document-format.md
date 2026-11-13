# Document format

`PRODUCT.md`, `KNOWLEDGE_BASE.md`, and `ARCHITECTURE.md` read like documentation written by the people who build the product: plain prose for a reader, no status markers, no line numbers, no SHAs. Evidence lives in one `Sources:` line per knowledge base entry or architecture part and in `PRODUCT_REVIEW.md`. In `PRODUCT.md` and `KNOWLEDGE_BASE.md`, code names appear only where the product itself uses them, in sources, and in the vocabulary; `ARCHITECTURE.md` names classes and files, since there they are the subject.

## Contents

- PRODUCT.md
- KNOWLEDGE_BASE.md
- ARCHITECTURE.md
- PRODUCT_REVIEW.md
- Agent instructions

## PRODUCT.md

The short product context agents design and build against. It records what must stay true; exact behaviour, limits, and edge cases belong in `KNOWLEDGE_BASE.md`. Keep it to one or two screens. A section whose content no source states stays out of the document; its question goes into the review list instead. Agents read it before every design or change of a feature, so each line has to tell it something it cannot read off the code in a moment: on coding agents, context files that repeat what the repository already shows lowered success slightly and raised cost by about a fifth, while facts the code does not reveal helped. Its value lies in the rules that hold across entry points, the vocabulary with its names in code, and what only a source states.

```md
# Product

## Platform

{web | API | console | library | ..., as a short list}

## Users

{Who comes to the product and what they come to do, one paragraph. Who can use it without an account. For a library: the developers of the applications that include it.}

## Product Purpose

{What the product is and what success looks like, two or three sentences.}

## Positioning

- **{What sets it apart}.** {Why a general alternative cannot claim the same.}

## Operating Context

- Surfaces: {every way in: web app, API, console, jobs, feeds, embeds, ...}
- {What guests can do, and what needs sign-in.}
- {Who operates or moderates it, by role; their workflows are entries in the knowledge base.}
- External systems: {system}: {what is exchanged}
- Exact behavior, limits, and edge cases for every feature live in [KNOWLEDGE_BASE.md](KNOWLEDGE_BASE.md) and in the code; this file only records what must stay true.

## Capabilities and Constraints

What exists, one line each (details in the knowledge base):

- **{Feature}:** {one line}

Rules every feature must keep:

- **{Rule as a short statement}.** {What it means at every entry point, with the concrete consequence.}

Deliberately excluded: {what the product never does, only as stated by a source}.

## Brand Commitments

- Name: **{name}**, {how it is written, and where a variant is used}.
- Voice: {tone of the interface texts, as a source states it or the texts consistently show}.
- Vocabulary: {each product term, what it means, and its name in code where it differs: a {thing} is a **{term}** (`{Model}`); never call it {synonym}.}

## Evidence on Hand

- {What real usage or proof exists, and what must never be fabricated.}

## Product Principles

1. **{Principle}.** {What it rules out in practice.}
```

- **From code:** Platform, Users, Operating Context, the feature list, the rules (what every entry point enforces), and the vocabulary (interface texts, status labels, translation files, model names).
- **From sources only** (documentation, history, knowledge sources): Purpose beyond what the product visibly does, Positioning, Deliberately excluded, Voice, Evidence on Hand, Product Principles.

## KNOWLEDGE_BASE.md

The internal reference for the team and its agents, one entry per feature, for every role that uses it, administrators and operators included. Each non-empty section is looked up on its own, with its parent headings as context, so every heading describes its topic and every entry stands on its own. Settings that change behaviour appear by key or variable name with the default the code sets; secrets, credentials, values from `.env`, and personal data never appear.

```md
# {Name} knowledge base

{What the product is in one or two sentences, introducing its own terms in bold.}

This file documents the product's features and stories. Feature entries describe the current implementation, including access requirements and limits, and can be retrieved independently. How the product is built is in [ARCHITECTURE.md](ARCHITECTURE.md).

## Contents

- [Repository](#repository)
- [Features](#features)
  - [{Feature}](#{anchor})

## Repository

{Where the code lives and whether it is public, when that is relevant to users.}

## Features

### {Feature, named as a user would}

{What the user does and sees, in the interface's own words: the labels in bold, where to find it (**Settings → Profile**), keyboard shortcuts, who may use it, the concrete limits a user meets (lengths, counts, durations, rate limits), what happens on failure, what changes for others, and what is stored, exported, or erased.}

{Further paragraphs for edge cases, related settings, and what the product deliberately does not do here.}

Sources: [{what it is}]({path}), [{what it is}]({path}).

{History: {the reason or decision behind it, as a source states it}, with a link. Only when a source states it.}

## Lore

{Stories behind names, mascots, and features, only as a source tells them.}
```

- **Describe, don't reference:** "A wishlist holds at most 50 products; the 51st shows **Wishlist full**", not "validated by `WishlistItemRequest`". The class goes into the `Sources:` line.
- **Sources** link to files relative to the repository root, named by what they are (`[wishlist validation](app/Http/Requests/WishlistItemRequest.php)`), without line numbers.
- **Access** is part of the entry: who can use it, what a guest sees, and what an administrator can do in addition.
- **Lifecycles:** an entry about a record with states names each state with the label users see, and who moves it from one to the next.

## ARCHITECTURE.md

The technical reference for the people who develop and run the product: what a new developer needs to find their way and what an operator needs to keep it running. It describes the structure the code actually has, not one it should have; where the code departs from its framework's conventions, that is stated, because a reader would otherwise assume the convention. It links to code instead of copying it, and names classes and files, since here they are the subject. A section without content stays out.

```md
# {Name} architecture

{What the product is technically, in one or two sentences: kind (application, API, package), framework, and how it is delivered.}

## Stack

- {Language, framework, frontend, database, cache, queue, search, mail, storage, hosting}: {what it is used for}

## Parts

### {Part, such as the admin area, the public API, the import}

{What it is responsible for, where it lives, and which parts it calls. Where it departs from the framework's conventions, how.}

Sources: [{what it is}]({path}).

## Main flows

### {Process, named as in the knowledge base}

{How a request or event passes through the parts, step by step: entry point, access check, validation, the classes that decide, what is stored, what is dispatched, what the actor gets back.}

## Data

{The core entities and how they relate, with the states a record moves through. Which tables other systems read or write.}

## External systems

- **{System}:** {what is exchanged, in which direction, through which client, and what happens when it is unavailable}. Sources: [{client}]({path}).

## Running it

- Outside a request: {each scheduled task, queue, and listener: when it runs and what it does}
- Configuration: {each setting that changes behaviour, by key or variable, with the default the code sets}
- Deployment: {how the product is built and released, as deployment and CI files show}
- Tests and checks: {the commands, and links to [tests/CHARACTERIZATION.md](tests/CHARACTERIZATION.md) and [QUALITY_GATE.md](QUALITY_GATE.md) when they exist}
```

- **From code:** Stack, Parts, Main flows, Data, External systems, Running it.
- **From sources only:** why a part is built the way it is. A decision found in an ADR, a pull request, or a commit message goes into the part with its link; without a source it stays out.
- **No secrets:** settings appear by name and default, never with a value from `.env`.

## PRODUCT_REVIEW.md

Material for the review, in the repository root, until people have worked through it.

```md
# Product review

Derived from {sha} on {date}. Repository: {path}. Knowledge sources used: {sources or none}.

## Security
What has to be closed before the repository is made public, and passed to whoever runs the product now.
- **{Security gap, in one sentence}.** {Who is affected and how.} `{path:line@sha}` | none

## Coverage
| Feature | Status | Read |
|---|---|---|
| {feature} | not studied / drafted / stale since {sha} | `{path:line}`, ... |

## To confirm
- {Statement in the documents that rests on a single reading of complex code, or on a source the code does not show}: `{path:line@sha}`

## Findings
- **{Finding}.** {What is wrong or contradictory, and the consequence for whom.} `{path:line@sha}`

## Review list
Where reviewers should start, most important first:
- {Section left out for lack of a source, a finding, or a statement to confirm, and why it matters}
```

## Agent instructions

One section in the file agents already read, so it adds the facts an agent cannot work out from the code and nothing it can: on coding agents, context files that repeat what the repository shows cost about a fifth more without improving results, and overviews of structure did not help agents find files.

- **Which file:** `AGENTS.md` when it exists, otherwise `CLAUDE.md` when it exists, otherwise a new `AGENTS.md` (Codex reads it, and Claude Code reads it when there is no `CLAUDE.md`). When both exist and `CLAUDE.md` does not import `AGENTS.md`, write to `AGENTS.md` and record as a finding that Claude Code does not read it.
- **Existing content:** keep everything else in the file. Replace only this section on a later run. Where the file contradicts what the code does, record a finding instead of changing it. If the file already exceeds 200 lines, record that as a finding instead of shortening it.
- **Commands:** only those the project defines (Composer and npm scripts, a `Makefile`, the README), copied exactly, never run.
- **Links:** only to files that exist. They are links, not imports (`@file`), so an agent reads a document when its task needs it.
- **Not in it:** a directory tree, an architecture or stack overview (that is `ARCHITECTURE.md`, linked), a description of files, anything the README already says, generic advice. The section adds no more than the file can take while staying under 200 lines.

```md
## Project knowledge

- [PRODUCT.md](PRODUCT.md): who the product is for, the rules every feature keeps, and its vocabulary. Read it before designing or changing a feature.
- [KNOWLEDGE_BASE.md](KNOWLEDGE_BASE.md): what each feature does, for which role, with its limits. Read the entry when a task touches that feature.
- [ARCHITECTURE.md](ARCHITECTURE.md): the parts, main flows, data, external systems, and operations. Read it before changing how parts work together or how the product runs.
- {[tests/CHARACTERIZATION.md](tests/CHARACTERIZATION.md): what the tests pin and what to do when one fails.}
- {[QUALITY_GATE.md](QUALITY_GATE.md): the quality gate, its values, and the decisions taken.}

Commands:

- All checks: `{command}`
- One test: `{command}`
- {Lint, static analysis, frontend build: `{command}`}

{Not visible in the code, only when a source states it:}

- {A decision or trap the code does not reveal, such as a rule enforced outside the repository, with its source}
```
