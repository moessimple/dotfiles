---
name: pr
description: Turn the current branch into a pull request whose description tells the problem and the outcome, then create it (or refresh an existing one) with gh after approval.
---

# Create or refresh a Pull Request

Turn the current branch into a pull request. Write the description for a reviewer who does not have your context: it carries the problem, the outcome, and, when the design is not obvious, the decision behind it. The line-by-line implementation stays in the diff; do not retell it in prose.

The skill has two modes, decided by whether a PR already exists for this branch:

- **Mode A (create):** no open PR for this branch yet. Write the description and open the PR.
- **Mode B (refresh):** an open PR already exists. Regenerate the description from the current branch and update the PR, so it never lags behind changes made after it was opened.

Both modes run the same context-gathering and the same prose craft. They differ only at the human checkpoint and the final `gh` call.

**REQUIRED SUB-SKILL:** Use the `outcome-writing` skill for every sentence of the title and description. It owns the prose craft (problem first, outcome over mechanism, precise terms but no code-internal names, and the self-review checklist). This skill owns only the PR-specific structure and mechanics below.

## Current state

Run and inspect:

- `git branch --show-current`
- `git status --porcelain`
- `git log --oneline -10`
- `gh pr view --json url,state --jq '.state + " " + .url' 2>/dev/null || echo none`

## Step 1: Preflight

Check the injected state above. Stop and tell the user if any of these apply:

- **On the default branch** (main or master). A PR needs a feature branch. Offer to create one that takes over the current commits.
- **Uncommitted changes exist.** They will not be part of the PR. Ask whether to commit them first or proceed without them.

When stopping, present the options as a short numbered list, not as an open question.

**Establish the mode** from the injected "Existing PR" line:

- `none` → **Mode A (create)**.
- `OPEN <url>` → **Mode B (refresh)**.
- `MERGED <url>` or `CLOSED <url>` → stop. Tell the user this branch's PR is already merged or closed; a fresh PR needs a fresh branch. Do not continue.

State the chosen mode in one sentence before moving on.

## Step 2: Gather context

Run sequentially, each step depends on the previous:

1. `gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'` to get the default branch
2. `git log {defaultBranch}...HEAD --oneline` for the commits on this branch. If empty, stop: there is nothing to open a PR for.
3. `git diff {defaultBranch}...HEAD` for all changes
4. **Mode B only:** `gh pr view --json title,body` for the PR's current title and description. This is the text you are about to replace; you need it to show a before/after and to spot hand-written content.
5. Read `SPEC*.md` (root, `docs/`, `docs/specs/`, or `spec/`; includes per-module `SPEC-<name>.md`), `tasks/plan.md`, and `tasks/todo.md` if they exist
6. Check the current conversation for a shipping report on these changes. If one exists, it feeds the Risks and Review focus sections. If it ended NO-GO, say so in one sentence and let the user decide, do not block.

**Verify the artifacts match this branch before using them.** Spec and task files can be relics of earlier work. Cross-check them against the diff. Use an artifact only if it clearly describes this change. If it describes something else, ignore it, tell the user in one sentence that stale artifacts were ignored, and continue down the priority list below.

The **why** comes from, in order of priority:

1. The motivation supplied in the current request, if any
2. The spec file, the deliberate and curated source
3. The current conversation, if there was meaningful discussion about the motivation
4. **Mode B:** the "Why" already in the current PR description, if it still fits the diff
5. None of the above: ask the user once what the change does and why it was made

The **what changed** content prefers completed task descriptions from `tasks/todo.md` over re-deriving outcomes from the raw diff.

The **approach rationale** comes from the design discussion in the current conversation, a design or "alternatives considered" section in the spec, or an ADR. If none of those exist and the approach was not discussed, do not invent a rationale; leave the Approach section out.

Commit messages are never a source for the title or the story. They are often WIP commits and carry no reliable meaning. Use them only to see which commits belong to the branch.

## Step 3: Write title and description

Apply the `outcome-writing` skill throughout.

Write the description for the **whole branch diff against the default branch**, not just what changed since the PR was opened. In Mode B you are rewriting the description to match the current state, not appending a delta.

If a ship report exists, its Blockers, Recommended fixes, Acknowledged risks, and rollback trigger conditions are the primary source for the Risks and Review focus sections. Only add what the report missed. Without a report, derive them from the diff: migrations (rollback possible, data loss risk), behavior changes that could break callers, missing test coverage, changes to shared infrastructure, security implications.

The Verification section comes from what was actually run or checked during the session (test commands, manual checks, a shipping report's test evidence), never invented after the fact. If nothing was verified beyond writing the code, say so plainly rather than omitting the section.

The Approach section is a deliberate exception to the `outcome-writing` skill's "outcome over mechanism" rule: keep it through the self-review checklist even though the checklist would otherwise trim it. It still uses no code-internal names.

**Title.** A complete imperative sentence that states the outcome and stands alone, under 72 characters ("Validate payment details before checkout", not "Fix bug" or "Update OrderController"). Derive it in order of priority: the spec title, the plan's goal statement in `tasks/plan.md`, or the "Why" condensed to one line. Never from commit messages. If no artifact yields a clear title, ask the user.

**Description.** ALWAYS use this exact structure:

```markdown
## Why

{1 to 3 sentences. What was broken, missing, or painful before this change? What did the user or the system experience?}

## What changed

{1 to 3 sentences or short bullets. What is different now, described as outcome, not implementation.}

## Approach

{Only when the design is not the obvious one. 1 to 3 sentences: why this approach over the alternatives, what constraint forced it, what was rejected and why. The decision, not a walkthrough of files or functions.}
{If the approach follows directly from the problem: omit this section entirely.}

## Verification

{What was actually run or checked: commands, tests, manually verified scenarios. Note anything explicitly left untested.}

## Risks

- {Specific risk: what could go wrong, under what condition}
- {If none: omit this section entirely}

## Review focus

- {Where to look closely and why: specific method, migration, edge case}
- {For a user-visible change: a screenshot or a short note on what changed visually}
- {If nothing non-obvious and nothing visual: omit this section entirely}
```

Before showing the draft, run the `outcome-writing` self-review checklist against it. Revise until every check passes.

## Step 4: Human checkpoint

**Mode A.** Show the title and the full description, ask whether both fit, and state that the PR will only be created after confirmation.

**Mode B.** Show the current title and description next to the proposed ones, so the user sees exactly what changes. Then, before asking for approval:

- **Flag content that would be lost.** If the current description contains anything the regenerated version does not reproduce (hand-written notes, reviewer answers, linked issues or checklists, extra sections), list each item and ask whether to keep it. Do not drop it silently.
- **Detect a no-op.** If the regenerated description says the same things as the current one, tell the user the existing description already matches the branch and stop. Do not push an edit that only reshuffles words.

State that the PR will only be updated after confirmation.

Wait. Do not continue until the user explicitly approves (Rule 1). Treat hedged responses ("probably fine", "should be ok", "looks fine I guess") as NOT approved. If they request changes, apply them and show the updated description again before continuing.

## Step 5: Create or update the PR

Everything below runs after the human checkpoint in Step 4. Pushing and the `gh` write rely on the session's own permission settings. Expect a permission prompt when required.

**Mode A (create):**

1. Push: `git push -u origin HEAD`
2. Check for an existing PR: `gh pr view --json url --jq '.url'`. If a URL is returned, the PR already exists (it was opened since preflight). Switch to Mode B step 2 below instead of creating a duplicate.
3. Create with the approved title and description:

```bash
gh pr create --title "the title" --body "$(cat <<'EOF'
## Why
...
EOF
)"
```

**Mode B (refresh):**

1. Push any new local commits: `git push`
2. Update the PR with the approved title and description:

```bash
gh pr edit --title "the title" --body "$(cat <<'EOF'
## Why
...
EOF
)"
```

Return the PR URL.

## Rules

1. Never create or update the PR before the human approved the description. Not even for trivial changes.
2. No AI attribution anywhere in the PR: no "Generated with" footer, no co-author line, no mention of Claude. No "Test plan" section either.
3. Never open or refresh the PR for a change you cannot explain yourself. If a hunk in the diff does not trace to a reason you can state, say so to the user before writing the description, do not paper over it with vague prose.
4. In Mode B, never discard hand-written content from the existing description without the user's explicit say-so (Step 4).

## Definition of Done

- Title and description follow the `outcome-writing` skill consistently throughout
- The "Why" section describes an experience or problem, not a diff
- When the design is not obvious, the description states why this approach and what was rejected; when it is obvious, no Approach section was added
- The description covers the whole branch diff, not just changes since the PR was opened
- Every part of the diff is accounted for in the description or was flagged to the user
- The human explicitly approved the description before `gh pr create` / `gh pr edit` ran
- Mode B: content that only lived in the old description was either carried over or explicitly dropped with the user's approval
- The PR body contains no AI attribution
- The PR URL is returned and accessible
