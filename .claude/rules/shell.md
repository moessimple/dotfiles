---
paths:
  - "**/*.sh"
  - "**/*.bash"
  - "**/*.bats"
  - "home/.{zshrc,zprofile,aliases,exports,functions,paths}"
  - "home/.config/git/default-branch"
  - "home/.claude/skills/php-lsp-herd/bin/intelephense-herd"
---

## Shell conventions

These conventions apply to the repository's own shell code, excluding third-party skills:

- Use `#!/bin/bash` for Bash scripts and `#!/usr/bin/env zsh` for zsh helpers to keep interpreters predictable.
- Setup entry points use `set -e`; hooks in `home/.claude/hooks/` use `set -u` and check statuses explicitly;
  standalone helpers and skill scripts use `set -euo pipefail`, matching how they handle failure.
- Use `[[ … ]]` for strings/files and `(( … ))` only as integer conditions, so a zero-valued arithmetic
  statement cannot accidentally trigger `errexit`.
- Define functions as `name() {` without `function`, keeping one definition style.
- Use snake_case; reserve uppercase for constants, declaration lists, and required environment names.
  Private function prefixes belong to interactive zsh helpers, where they keep completion and names tidy.
- Group unassigned locals and separate declarations from command substitutions to preserve exit statuses.
- Quote every expansion, assignments included (`value="$(command)"`, `path="$dir/file"`), as Google's Shell Style
  Guide does. Bash and zsh do not split or glob assignment values, so the quotes change nothing there; one rule
  without that exception stays correct when a value is moved into an argument or an array.
- Suppress both output streams with `&>/dev/null` and redirect errors with `>&2`, using one spelling each.
- Setup reports through `support/setup/output.sh`; other errors go to stderr with a failing return or exit,
  so callers can distinguish diagnostics from normal output.
- Use explicit `if` blocks for argument checks, making each error and return visible.
- Check `-h`/`--help` before argument validation, print usage to stdout, and return 0 so help does no work.
- Setup files define variables/functions; entry points call them explicitly, keeping
  sourcing free of machine changes.
- Name functions verb first, after the action and its subject (`install_npm_packages`, `wait_for_herd_onboarding`),
  so an entry point reads as the sequence of steps it runs. Predicates start with `is_` or `has_`, functions that
  print a value with `print_` or `read_`, and a wrapper around one command keeps that command's name (`global_npm`,
  `skills_cli`).
- Keep only contract or constraint comments under `home/.claude/rules/code-comments.md`; shared rationale
  belongs in this rule to avoid repetition.
- Do not use en or em dashes as punctuation, including output strings, matching the writing rules.
- The function doing a step prints its own `step` and result; entry points print their own frame and
  `finish`, keeping reporting with the work it describes.

Exceptions: `home/.config/git/default-branch` is deliberately POSIX `sh`. Preserve Herd's injected blocks in
`home/.zshrc` as written by Herd. `support/git/support/pickaxe-diff.sh` adds `-E` so its ERR trap is inherited.
The `_rpr_*` locals in `home/.claude/hooks/support/project-root.sh` prevent output-parameter names from shadowing
caller variables; their prefix is a collision guard. `home/.claude/statusline.sh` runs without strict mode, so
input it cannot parse still prints a status line instead of an empty one. Bats tests use `[ … ]` for assertions:
under the macOS `/bin/bash` 3.2, a failing `[[ … ]]` or `(( … ))` that is not the last command does not fail
the test.

Separate `local` declarations from command substitutions because `local` otherwise masks the command's exit
status. Capture pipelines with `pipefail` in a subshell and check the result before iterating, so a failed
package-manager query cannot become an apparently empty installed set.

A cleanup function's final success message belongs in an explicit `if`, rather than `condition && success`:
a false condition would return 1 and stop `bin/update.sh` under `set -e`, even though no step failed.
