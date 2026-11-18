# AGENTS.md

This file provides guidance to Claude Code and Codex when working with code in this repository.

## What this is

Personal, opinionated dotfiles for Laravel/PHP development on macOS (Herd, Oh My Zsh, modern CLI tools, a
version-controlled Claude Code configuration). There is no build step and no application code; changes take effect
by symlinking files into `$HOME` and by shell scripts that install/configure the machine.

## Source of truth

The goal is to keep every managed configuration and package in sync with this repository at all times. This
repository is the sole source of truth for that state. Changes to setup and
update logic must preserve that authority: apply the repository's files and declarations rather than silently
keeping or merging conflicting machine state. Lasting changes to managed settings belong in the repository.
Edits through symlinks already change repository files; treat them as working-tree changes, not disposable drift.
Backups may preserve previous state, but must not become an alternative source of configuration or prevent the
declared state from being applied.

The current implementation does not fully enforce this goal: `bin/install.sh`, `bin/reconfigure.sh`, and
`bin/update.sh` have different scopes, documented in [ARCHITECTURE.md](ARCHITECTURE.md#setup-entry-points). macOS defaults are deliberately applied only during install
or through `bin/macos-defaults.sh`, not during update or reconfigure. Other gaps in synchronization are
implementation limitations, not exceptions to the goal or reasons to preserve drift. Only reconcile explicitly managed
state. Machine-specific settings and secrets (such as `~/.extra`, `~/.gitconfig-local`, and the saved machine
profile), runtime data, and independently managed installations stay outside that scope unless explicitly declared.

## Commands

Run the Bats test suite from the repository root:

```zsh
bin/test.sh
```

Run a single test file:

```zsh
bin/test.sh tests/claude/hooks/quality-gate.bats
```

Filter to tests matching a name:

```zsh
bin/test.sh -r tests/ -f "some test name"
```

Format every tracked Bash, Bats, and zsh script with shfmt, or only check the formatting:

```zsh
bin/format.sh
bin/format.sh --check
```

## Read before changing a subsystem

Read the matching sections of [ARCHITECTURE.md](ARCHITECTURE.md) before changing an existing subsystem or
adding files to it. Read only the sections relevant to the task, then inspect the source and tests they name.
The architecture is shared reference documentation for contributors and agents; this file holds working rules.

| Work | Read first |
| --- | --- |
| Install, reconfigure, update, machine profile, services, or SSH setup (`bin/install.sh`, `bin/reconfigure.sh`, `bin/update.sh`, `bin/macos-defaults.sh`, `bin/setup-ssh.sh`, `support/setup/`, `support/config/Brewfile`) | [Setup entry points](ARCHITECTURE.md#setup-entry-points); for symlinks, also [Home directory preparation](ARCHITECTURE.md#home-directory-preparation) |
| Plugin, skill, or package release-age handling (`support/setup/claude/`, `support/setup/packages/`, `home/.claude/settings.json`) | [Update cooldown](ARCHITECTURE.md#update-cooldown) |
| Hooks (`home/.claude/hooks/`), their tests, or the `quality` function in `home/.functions` | [Quality gate](ARCHITECTURE.md#quality-gate) and [Hook behavior](home/.claude/hooks/README.md) |
| Git helpers (`support/git/`), Git configuration, shell startup, or Git-related functions in `home/.functions` | [Git helpers](ARCHITECTURE.md#git-helpers) |
| Adding or changing tests (`tests/`) | [Test layout and fixtures](ARCHITECTURE.md#test-layout-and-fixtures) |
| Test runner, formatter, CI, or `.editorconfig` | [Verification tooling](ARCHITECTURE.md#verification-tooling) |

Tests mirror the source layout under `tests/`; check the test map before creating a test file. Setup files define
functions without running setup when sourced. Calling those functions with the real `HOME` and `PATH` changes
the machine: inspect their source or use fixture `HOME` and `given_fake_bin_on_path` to explore behavior.

## Shared configuration

**`home/` mirrors `$HOME`.** Every file under `home/` except `home/.claude/AGENTS.md` (see below) is symlinked to the
same relative path below `$HOME` (e.g. `home/.zshrc` → `~/.zshrc`, `home/.claude/skills` → `~/.claude/skills`).
Editing the path in either location changes the file tracked in this repository.
`support/setup/dotfile-links.sh` is the single source of truth for which paths are linked and whether a given path
is linked as a file (`ln -sf`) or as a directory (`ln -sfn`, used for `.claude/agents`, `.claude/commands`,
`.claude/hooks`, `.claude/rules`, `.claude/skills`).

`home/.claude/AGENTS.md` holds the global instructions and is the one exception to the mirror: `dotfile-links.sh`
links it as `~/.claude/CLAUDE.md`, the only name Claude Code reads user-level instructions from, and as
`~/.codex/AGENTS.md` for Codex, so both share one file instead of two copies. A Claude Code session started in
`home/` also reads `home/.claude/AGENTS.md` as project instructions and so loads the global instructions twice;
start sessions in the repository root.
`support/setup/codex/codex-skills.sh` links explicitly reviewed harness-neutral skills from `home/.claude/skills/` and
Claude's installed plugin cache into `~/.agents/skills`.
Claude remains the only installer and updater. Shared workflows keep their instructions in one `SKILL.md`. Skills
with agent-specific tools, paths, or runtime behavior stay exclusive to that agent.

## Declared list = desired state

The Brewfile (`support/config/Brewfile`), global Composer/npm/Python package lists
and Ollama models (`support/setup/packages/`), Claude Code skills/plugins (`support/setup/claude/claude-skills.sh`,
`claude-plugins.sh`), user-scope MCP servers (`CLAUDE_MCP_SERVERS` in `claude-plugins.sh`), Codex-compatible skills
(`support/setup/codex/codex-skills.sh`), and plugin marketplaces
(`extraKnownMarketplaces` in `home/.claude/settings.json`) are each treated as the full desired state.
`install_claude_plugins` and `clean_up_claude_plugins` in `support/setup/claude/claude-plugins.sh` read that
marketplace declaration instead of maintaining a second URL list. Marketplace cleanup uses the CLI to remove
undeclared registry entries; this also uninstalls their plugins and can delete saved plugin data. Marketplaces
needed by project/local plugins are retained. Removal runs from `$HOME` so the CLI cannot change declarations
in the calling project. An unreadable plugin listing prevents marketplace cleanup.
After each update step, `bin/update.sh` removes anything installed but not declared: Homebrew and
Mac App Store apps (the Brewfile's `mas` entries) via `brew bundle cleanup --force` in
`support/setup/packages/homebrew-packages.sh`, the others via a
`clean_up_*` function in the declaring file, while `codex-skills.sh`
prunes its own stale links on every run. When adding a package or skill, add it to the declaration; do not
install it out of band, or the next `update.sh` run removes it. Run the third-party skill review below before
adding a skill to `support/setup/claude/claude-skills.sh`. Add a source to `CODEX_COMPATIBLE_SKILLS` or
`CODEX_COMPATIBLE_CLAUDE_PLUGIN_SKILLS` only after confirming that its full directory is harness-neutral and does not
duplicate a Codex skill.

This repository decides where a skill or plugin belongs; check it before adding one by any route (a declaration
above or a folder under `home/.claude/skills/`). A skill here is available in every project, work projects included,
and Claude Code lets a personal skill shadow a project skill of the same name. It belongs here only if it fits a
project whose team decided differently, takes the standards code is measured against (style, architecture, test
style, thresholds) from the project instead of bringing its own, and tells the model something it does not already
know. Otherwise it belongs to the project (its `.claude/skills`, Laravel Boost, or a Composer package). The
deliberate exceptions are `document-product`, `characterize-behavior`, and `raise-quality-gate`: they bring their own
standards on purpose, to develop legacy projects safely, and run only when invoked by name.

### Third-party skill review

Before adding an entry to `support/setup/claude/claude-skills.sh`, follow this manual checklist:

1. Read every file in the skill, including referenced Markdown and scripts, rather than only its description.
2. Search for network calls (`curl`, `fetch`, `requests`, `urllib`) and confirm every destination is expected.
3. Search for credential, cookie, or Keychain access (`security find-generic-password`, browser profiles,
   `~/.ssh`, `~/.aws`) and confirm a legitimate reason for it.
4. Check for hardcoded API keys, tokens, or passwords.
5. Look for instructions to ignore safety rules, hide actions, or behave differently for specific inputs.
6. List every shell command and tool the skill asks the agent to invoke. Assess the combined risk when file
   reads and network access appear together.
7. Check that referenced external URLs point to the expected domains.
8. Treat High or Critical findings from the CLI's Gen/Socket/Snyk audit as a reason to inspect carefully, not as
   a substitute for this review or a reliable signal by themselves. Those audits can be wrong or miss risks.

Adapted from [Anthropic's review checklist](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/enterprise#review-checklist).

TODO: Automate a pre-install scan for network calls, credential/Keychain/cookie access, and hardcoded secrets
before `skills_cli add`, so review does not depend on remembering this checklist.

Add each new `THIRD_PARTY_SKILLS` entry from `support/setup/claude/claude-skills.sh` to the third-party ignore
list in `.editorconfig`, so `bin/format.sh` leaves its scripts as upstream wrote them.

## Test conventions

Tests assert observable files, Git state, output, exit status, and public command contracts. Do not assert source
spelling, private helper names, arbitrary step ordering, or prose formulations. Static checks are appropriate for
declarative configuration and shared document formats consumed by other tools or skills. At external boundaries
that cannot safely run in tests, check command arguments and failure handling; use real tools with isolated data
when practical. `tests/bin/macos-defaults.bats` records privileged calls without executing them and confines real
PlistBuddy writes to its fixture HOME. These tests do not prove that macOS accepts every declared preference or
that a fresh machine can install every external package.

Read tests as behavior documentation. Each `@test` name identifies the command or process, the relevant condition,
and the expected outcome. A reader must be able to understand the preparation, action, and expectations without
reading the production implementation or tracing fixture internals. Arrange the scenario-specific state in the
test; use `setup` for a clearly visible shared baseline and helpers for mechanical fixture construction. Helpers
must not hide the values or conditions that explain the scenario. Assertions state the expected values and effects
explicitly. A call count alone does not prove which database was migrated or which file was imported.

Every test body starts with a section comment and marks its sections with `# Arrange`, `# Act`, and `# Assert`,
omitting a section that has no code (a static check over repository files has only `# Assert`). A marker may add a
short description after a colon, such as `# Arrange: one CPU and a separate PHPUnit database.` A lifecycle test
repeats `# Act:` and `# Assert:` for each transition and names the transition in the description. Markers stay at
the test's top level, never inside a loop: run several cases in one `# Act` section and assert the collected result,
or give each case its own test.

Give distinct conditions and failure modes separately named tests. When a test covers a lifecycle, make each state
transition and its expectations clear. Put single-command scenarios in that command's test file and source-only
checks in `tests/setup/sourcing.bats`. Keep cross-component scenarios together with the behavior they document,
such as the edit-to-stop lifecycle or the machine profile shared by the setup entry points.

Before finishing test changes, read the changed scenarios as documentation. Verify that each name matches the
actual preparation and assertions, that the important conditions and expected results are explicit, and that the
test is located with the behavior it protects. Passing tests alone do not satisfy this review.

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
  belongs here to avoid repetition.
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

## Conventions specific to this repo

- Machine-specific or secret shell configuration goes in `~/.extra` (sourced by `.zshrc`, never committed), not in
  any file under `home/`.
- Herd is the exception. Its installer and its NVM/PHP shims append machine-specific lines to `~/.zshrc` (absolute
  `/Users/<name>/Library/Application Support/Herd/...` paths, per-version `HERD_PHP_*_INI_SCAN_DIR` exports, a
  repeated "Herd injected PHP binary" block). Because `~/.zshrc` is a symlink into `home/.zshrc`, those writes land
  in the tracked file and are committed as-is. This is expected: do not relocate Herd's injected blocks to `~/.extra`
  or rewrite their absolute paths, and expect Herd to re-add or reorder them on the next install/update.
- `home/.claude/AGENTS.md` (see Shared configuration) is a different file from this one: it applies to every project, not
  just this repo.
- `home/.functions` stays a single file, sourced whole by `.zshrc`, grouped by `# === section ===` headers. The
  one-function-per-file split under `support/git/` is deliberate for that set (a coherent group with its own Bats
  suite and shell-startup sourcing loop), not a pattern to extend here. Do not split `home/.functions` into
  per-topic files without a concrete reason; add new helpers under the matching section header.
- The `precmd` `_fix_tty` hook in `.zshrc` runs `stty sane` before every prompt on purpose. Interactive tools that
  exit uncleanly (artisan prompts, some TUIs) leave the terminal in a broken state; repairing it on every prompt is
  the accepted cost. Keep it unless it is shown to clobber a deliberate `stty` setting in practice.

## Documentation maintenance

`README.md` is written for people who fork this repository and doubles as the owner's reference: what the setup
does, what to check before installing, how to install, update, and adapt it, and which commands it adds.
`AGENTS.md` holds the working rules and reading map, `ARCHITECTURE.md` explains the system and its decisions
for contributors and agents, `home/.claude/hooks/README.md` documents the quality gate, and
`home/.claude/AGENTS.md` holds the global instructions for every project, including the skills and tools they name.
Some facts appear in more than one of these documents on purpose, so a change can make several of them wrong at once.

- After changing a file, search all five documents for its repository path (and, for a file under `home/`, also
  its `~/` path) and check every match against the new behavior. Update them in the same change.
- When adding something a user runs or invokes (a script under `bin/`, an alias, a function, a Git helper, a skill
  in a Codex allowlist, a declared package), decide whether `README.md` should mention it.
- When a sentence in one of these documents describes what a specific file does, name or link that file, so the
  search above finds the sentence.
- Never leave a line that contradicts the code.
