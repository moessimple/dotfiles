---
description: Turn the current branch into a pull request whose description tells the problem and the outcome, then create it with gh after approval.
argument-hint: "[optional short description of the why]"
disable-model-invocation: true
allowed-tools: Bash(git branch:*), Bash(git status:*), Bash(git log:*), Bash(git diff:*)
---

# Create a Pull Request

Turn the current branch into a pull request. The description tells the story of the problem and the outcome. The diff tells the implementation. Never mix the two.

**REQUIRED SUB-SKILL:** Use the `outcome-writing` skill for every sentence of the title and description. It owns the prose craft (problem first, outcome over mechanism, precise terms but no code-internal names, and the self-review checklist). This command owns only the PR-specific structure and mechanics below.

## Current state

- Branch: !`git branch --show-current`
- Uncommitted changes: !`git status --porcelain`
- Recent commits: !`git log --oneline -10`

## Step 1: Preflight

Check the injected state above. Stop and tell the user if any of these apply:

- **On the default branch** (main or master). A PR needs a feature branch. Offer to create one that takes over the current commits.
- **Uncommitted changes exist.** They will not be part of the PR. Ask whether to commit them first or proceed without them.

When stopping, present the options as a short numbered list, not as an open question.

## Step 2: Gather context

Run sequentially, each step depends on the previous:

1. `gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'` to get the default branch
2. `git log {defaultBranch}...HEAD --oneline` for the commits on this branch. If empty, stop: there is nothing to open a PR for.
3. `git diff {defaultBranch}...HEAD` for all changes
4. Read `SPEC.md` (root, `docs/`, or `spec/`), `tasks/plan.md`, and `tasks/todo.md` if they exist
5. Check the current conversation for a `/ship` report on these changes. If one exists, it feeds the Risks and Review focus sections. If it ended NO-GO, say so in one sentence and let the user decide, do not block.

**Verify the artifacts match this branch before using them.** Spec and task files can be relics of earlier work. Cross-check them against the diff. Use an artifact only if it clearly describes this change. If it describes something else, ignore it, tell the user in one sentence that stale artifacts were ignored, and continue down the priority list below.

The **why** comes from, in order of priority:

1. Arguments passed to this command, if any: $ARGUMENTS
2. The spec file, the deliberate and curated source
3. The current conversation, if there was meaningful discussion about the motivation
4. None of the above: ask the user once what the change does and why it was made

The **what changed** content prefers completed task descriptions from `tasks/todo.md` over re-deriving outcomes from the raw diff.

Commit messages are never a source for the title or the story. They are often WIP commits and carry no reliable meaning. Use them only to see which commits belong to the branch.

## Step 3: Write title and description

Apply the `outcome-writing` skill throughout.

If a ship report exists, its Blockers, Recommended fixes, Acknowledged risks, and rollback trigger conditions are the primary source for the Risks and Review focus sections. Only add what the report missed. Without a report, derive them from the diff: migrations (rollback possible, data loss risk), behavior changes that could break callers, missing test coverage, changes to shared infrastructure, security implications.

The Verification section comes from what was actually run or checked during the session (test commands, manual checks, a `/ship` report's test evidence), never invented after the fact. If nothing was verified beyond writing the code, say so plainly rather than omitting the section.

**Title.** A complete imperative sentence that states the outcome and stands alone, under 72 characters ("Validate payment details before checkout", not "Fix bug" or "Update OrderController"). Derive it in order of priority: the spec title, the plan's goal statement in `tasks/plan.md`, or the "Why" condensed to one line. Never from commit messages. If no artifact yields a clear title, ask the user.

**Description.** ALWAYS use this exact structure:

```markdown
## Why

{1 to 3 sentences. What was broken, missing, or painful before this change? What did the user or the system experience?}

## What changed

{1 to 3 sentences or short bullets. What is different now, described as outcome, not implementation.}

## Verification

{What was actually run or checked: commands, tests, manually verified scenarios. Note anything explicitly left untested.}

## Risks

- {Specific risk: what could go wrong, under what condition}
- {If none: omit this section entirely}

## Review focus

- {Where to look closely and why: specific method, migration, edge case}
- {If nothing non-obvious: omit this section entirely}

## Documentation and visuals

- {Only for user-visible/UI changes: a screenshot or short description of what changed visually}
- {If not applicable: omit this section entirely}
```

Before showing the draft, run the `outcome-writing` self-review checklist against it. Revise until every check passes.

## Step 4: Human checkpoint

Show the title and the full description, ask whether both fit, and state that the PR will only be created after confirmation.

Wait. Do not continue until the user explicitly approves (Rule 1). Treat hedged responses ("probably fine", "should be ok", "looks fine I guess") as NOT approved. If they request changes, apply them and show the updated description again before continuing.

## Step 5: Create the PR

Everything below runs after the human checkpoint in Step 4, so an `allowed-tools` grant from
this command's frontmatter has already expired: that grant lasts one turn and clears with the
user's next message. Pushing and creating the PR therefore rely on the session's own permission
settings. Expect a prompt at `gh pr create`, which is deliberate.

1. Push: `git push -u origin HEAD`
2. Check for an existing PR: `gh pr view --json url --jq '.url'`. If a URL is returned, the PR already exists. Show the URL and stop.
3. Create with the approved title and description:

```bash
gh pr create --title "the title" --body "$(cat <<'EOF'
## Why
...
EOF
)"
```

Return the PR URL.

## Rules

1. Never create the PR before the human approved the description. Not even for trivial changes.
2. No AI attribution anywhere in the PR: no "Generated with" footer, no co-author line, no mention of Claude. No "Test plan" section either.
3. Never open the PR for a change you cannot explain yourself. If a hunk in the diff does not trace to a reason you can state, say so to the user before writing the description, do not paper over it with vague prose.

## Definition of Done

- Title and description follow the `outcome-writing` skill consistently throughout
- The "Why" section describes an experience or problem, not a diff
- Every part of the diff is accounted for in the description or was flagged to the user
- The human explicitly approved the description before `gh pr create` ran
- The PR body contains no AI attribution
- The PR URL is returned and accessible
