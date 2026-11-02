# Document format

Both documents read like documentation written by the people who build the product: plain prose for a reader, no status markers, no line numbers, no SHAs. Evidence lives in one `Sources:` line per knowledge base entry and in `PRODUCT_REVIEW.md`. Code names appear only where the product itself uses them, in sources, and in the vocabulary.

## Contents

- PRODUCT.md
- KNOWLEDGE_BASE.md
- PRODUCT_REVIEW.md

## PRODUCT.md

The short product context agents design and build against. It records what must stay true; exact behaviour, limits, and edge cases belong in `KNOWLEDGE_BASE.md`. Keep it to one or two screens. A section whose content no source states stays out of the document; its question goes into the review list instead. An agent reads it in every session, so each line has to tell it something it cannot read off the code in a moment: on coding agents, context files that repeat what the repository already shows lowered success slightly and raised cost by about a fifth, while facts the code does not reveal helped. Its value lies in the rules that hold across entry points, the vocabulary with its names in code, and what only a source states.

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
- {Who operates or moderates it, by role, without routes or workflows.}
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

Public documentation for ordinary users, one entry per feature. Each non-empty section is retrieved on its own, with its parent headings as context, so every heading describes its topic and every entry stands on its own. Nothing sensitive: no admin routes or dashboards, privileged workflows, configuration values (except a library's configuration keys and defaults, which consumers set), environment variables, secrets, queue internals, or abuse-relevant thresholds.

```md
# {Name} knowledge base

{What the product is in one or two sentences, introducing its own terms in bold.}

This file documents the product's features, stack, and stories. Feature entries describe the current implementation, including access requirements and limits, and can be retrieved independently. Technology names intentionally have no version numbers.

## Contents

- [Repository](#repository)
- [Features](#features)
  - [{Feature}](#{anchor})
- [Stack and hosting](#stack-and-hosting)

## Repository

{Where the code lives and whether it is public, when that is relevant to users.}

## Features

### {Feature, named as a user would}

{What the user does and sees, in the interface's own words: the labels in bold, where to find it (**Settings → Profile**), keyboard shortcuts, who may use it, the concrete limits a user meets (lengths, counts, durations, rate limits), what happens on failure, what changes for others, and what is stored, exported, or erased.}

{Further paragraphs for edge cases, related settings, and what the product deliberately does not do here.}

Sources: [{what it is}]({path}), [{what it is}]({path}).

{History: {the reason or decision behind it, as a source states it}, with a link. Only when a source states it.}

## Stack and hosting

{The frameworks and services the product runs on, as far as they are not sensitive, without version numbers.}

## Lore

{Stories behind names, mascots, and features, only as a source tells them.}
```

- **Describe, don't reference:** "A wishlist holds at most 50 products; the 51st shows **Wishlist full**", not "validated by `WishlistItemRequest`". The class goes into the `Sources:` line.
- **Sources** link to files relative to the repository root, named by what they are (`[wishlist validation](app/Http/Requests/WishlistItemRequest.php)`), without line numbers.
- **Access** is part of the entry: who can use it, what a guest sees, and what an administrator can do in addition.
- **Lifecycles:** an entry about a record with states names each state with the label users see, and who moves it from one to the next.

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

## Kept out as sensitive
- {Admin or operations behaviour, configuration, or threshold left out of the documents}: `{path}`
```
