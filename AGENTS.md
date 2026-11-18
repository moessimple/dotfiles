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
`bin/update.sh` have different scopes, documented below. macOS defaults are deliberately applied only during install
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

`bin/test.sh` runs the files concurrently via `bats --jobs`, because the suite is almost entirely process-spawn
wait rather than CPU. The parallel backend is `rush` (Brewfile: `rush-parallel`, already a dependency) rather than
GNU `parallel`, selected with `--parallel-binary-name`. Job count defaults to the core count; set `BATS_JOBS=1` to
run serially when debugging a test that only fails under concurrency. Fixtures keep all mutable state under
`$BATS_TEST_TMPDIR`, so tests are order-independent and safe to parallelize.

`bin/test.sh` prepends a temporary `bash` link to `/bin/bash` to PATH for Bats and its subprocesses,
including fake executables. This keeps the suite on macOS Bash 3.2 even when Homebrew's Bash is installed.
The link is removed when the runner exits, including on failure.

A quiet start followed by bursts of output is not a hang. Most of the wall time is macOS `syspolicyd` assessing each
freshly written fake-binary stub (`write_fake_binary` in `tests/support/test_helper.bash`) on its first exec. That
check is serial and cannot be skipped, so more jobs do not shorten it. Cutting it would mean creating the stubs once
per file instead of once per test.

Format every tracked Bash, Bats, and zsh script with shfmt, or only check the formatting:

```zsh
bin/format.sh
bin/format.sh --check
```

The style lives in `.editorconfig`, because shfmt ignores it as soon as a style flag is passed on the command line:
4-space indent plus `-ci -bn`, the options shfmt's documentation names for Google's Shell Style Guide.
`bin/format.sh` passes only tracked files, adds the zsh dotfiles by name because shfmt does not detect them, and
leaves out `home/.zshrc` and `home/.zprofile` (Herd and Docker Desktop write into them) and the third-party skills
under `home/.claude/skills/`, which update reinstalls from upstream. Adding a third-party skill to `THIRD_PARTY_SKILLS`
in `support/setup/claude/claude-skills.sh` means adding it to the ignore list in `.editorconfig` too.

CI (`.github/workflows/tests.yml`) runs `bin/test.sh` on `macos-latest`, matching the interpreter and userland
(`/bin/bash` 3.2, BSD tools) the target machine actually has, with `bats-core`, `php`, `patchutils`, and
`rush-parallel` installed via Homebrew. `.github/workflows/lint.yml` runs `bin/format.sh --check` with Homebrew's
`shfmt` as its own workflow, so a formatting failure never hides a test result. Each workflow file, its `name`, and
its single job share one name (`tests`, `lint`). The `main` ruleset requires both checks by job name; renaming a
job means updating the ruleset in the same change.

There is no build step and no static analysis. Bash and zsh get the same checks, formatting and tests: ShellCheck
covers only Bash, and no zsh linter is mature enough to depend on, so neither language gets one.

## Architecture

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

**Entry points vs. setup logic.** Files in `support/setup/` define variables and functions; sourcing them does
not run setup. Each script under `bin/` sources every setup file it uses in one block after `set -e`, always from
`~/.dotfiles`, the fixed location the symlinks and aliases already depend on. It then calls those functions
explicitly, and each function prints its own step and result. Every step that changes machine state is such a
function, even with a single caller: its name states the step's intent, and it can be tested without running the
whole entry point. An entry point keeps only its own frame (confirmation prompts, `sudo -v`, `bin/update.sh`
re-running itself after the pull, `finish`, closing notes). Entry points group their steps under
`# === section ===` headers, as `home/.functions` does. `bin/macos-defaults.sh` is the exception: a linear list
of `defaults` commands under section headers, where the headers already name each part. `wait_for_herd_onboarding` in `support/setup/herd/herd-onboarding.sh` waits for Herd's CLI,
`install_herd_xdebug` in `support/setup/herd/herd-xdebug.sh` writes Xdebug configuration, and `set_up_tinkerbench`
in `support/setup/tinkerbench.sh` prepares the local project.

Scripts under `bin/` orchestrate these functions:

- `bin/install.sh` performs a full fresh setup, ending with `bin/macos-defaults.sh`.
- `bin/reconfigure.sh` reapplies symlinks, Codex skill links, services, and Herd/tinkerbench setup without package
  updates or an unconditional sudo request.
- `bin/update.sh` pulls the repo, updates managed packages, skills, plugins, and Ollama models, then runs
  `bin/reconfigure.sh`. It reports completion only if that succeeds. After the pull it `exec`s the pulled
  `~/.dotfiles/bin/update.sh` with `DOTFILES_UPDATE_PULLED=1`, which skips the pull, so the rest of the run never
  mixes the old script with the pulled setup files.
- `bin/macos-defaults.sh` (alias `macos-defaults` in `home/.aliases`) applies macOS preferences directly,
  with confirmation, sudo, and application termination.

Failure handling follows `brew bundle`, using the helpers in `support/setup/output.sh`. A step that later steps
depend on stops the run: the profile, the `~/.dotfiles` checkout (`support/setup/dotfiles-checkout.sh`), and Homebrew itself (`support/setup/homebrew.sh`) through `error`,
`home-directories.sh` and the symlinks through `set -e` when one of their commands fails. Any other step that cannot
be completed, such as one package, PHP version, or service, reports it with
`warn` and the run goes on. `finish` ends install, reconfigure, and update: it prints the success message only when
nothing warned, and otherwise lists every warning and exits 1. `note` is for information that is not a problem
(an undeclared package being removed, a reminder to restart the terminal) and is never counted.

`install_herd_xdebug` in `support/setup/herd/herd-xdebug.sh` reapplies both managed Xdebug ini files on every install/reconfigure/update run,
replacing local changes. `start_services` in `support/setup/services.sh` likewise rewrites `/opt/homebrew/var/config.toml` with
`upgrade_db = true`, so the Meilisearch service migrates its local database after a version bump instead of
refusing to start.

`bin/setup-ssh.sh` runs before cloning on a fresh Mac. It generates an Ed25519 key, adds it to the SSH agent and
macOS Keychain, and copies the public key for manual registration on GitHub. It refuses to overwrite existing keys
and does not run as part of `bin/install.sh`.

`bin/install.sh`, `bin/reconfigure.sh`, and `bin/update.sh` read and validate the saved profile through
`load_machine_profile` in `support/setup/machine-profile.sh`. All three call it explicitly after sourcing;
sourcing the file alone does not read or set the profile. On its first run, `bin/install.sh` asks private/work,
saves the choice in `~/.config/dotfiles/profile`, and asks for the machine's Git email for either profile.
Private setup offers the existing global email as a default. Only `user.email` is written to the untracked
`~/.gitconfig-local`, which `home/.gitconfig` includes last; the name stays shared. `home/.gitconfig` has no email
fallback and sets `user.useConfigOnly = true`, so Git refuses commits without a configured email.
Later installs reuse the profile and ask only for the email if the local setting is missing or blank.
All profile selection and email setup logic lives in `set_up_machine_profile` in
`support/setup/machine-profile.sh`, which only `bin/install.sh` calls. Reconfigure and update never
prompt for profile or email and default to private without a saved profile. `support/config/Brewfile`
reads the same profile and excludes AusweisApp, Discord, OneCast and WhatsApp on work machines, including from the desired state
used by update's cleanup. Other packages and sudo steps are shared.

**Claude Code plugin and skill updates (`support/setup/claude/update-cooldown.sh`).** Neither Claude Code nor the
skills CLI has a release-age cooldown, so `update_skills_after_cooldown` in `claude-skills.sh` and
`update_plugins_after_cooldown` in `claude-plugins.sh` give them the same 3 days that Composer, npm, and Python
packages wait. Both ask `has_cooled_down` in `update-cooldown.sh`, which also holds `raise_npm_pins`: it raises the
npm versions pinned in those two files (the skills CLI and `chrome-devtools-mcp`) to the newest release that is at
least 3 days old.
`support/setup/packages/python-packages.sh` passes `--uploaded-prior-to P3D` only to pip install and update
(requires pip 26.1+, with upload-time metadata from the index). The upstream state (a
skill's folder; a plugin's folder plus its `marketplace.json` entry) is installed only after it has been seen
unchanged for 3 days, counted from its first sighting in
`${XDG_CONFIG_HOME:-$HOME/.config}/claude-update-cooldown/first-seen`, never from a commit date. A marketplace is
refreshed only when every declared plugin from it has passed the cooldown, because Claude Code reads each plugin's
marketplace entry (inline LSP/MCP servers, hooks) from the refreshed checkout on every start. Like Composer and
npm, held-back versions are not announced and updates after the cooldown are not confirmed. `"autoUpdate": false`
on every `extraKnownMarketplaces` entry in `home/.claude/settings.json` keeps Claude Code from updating plugins
itself; `claude-plugins.sh` sets it again after `claude plugin marketplace add`.

**Declared list = desired state.** The Brewfile (`support/config/Brewfile`), global Composer/npm/Python package lists
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

**`support/setup/home-directories.sh` prepares directories and clears paths for symlinks.** Its `prepare_home_directories`
creates `~/Screenshots`, `~/Temp`, `~/Code`, `~/.config/ghostty`, `~/.config/git`, `~/.claude`, and `~/.codex`,
and an empty `~/.extra` when none exists.
`support/setup/dotfile-links.sh` defines `link_dotfiles`, which uses `ln -sf`/`ln -sfn` for every
managed path. Those commands already replace an existing file or symlink, but cannot replace a real directory,
so `prepare_home_directories` clears the five `~/.claude/` paths (`agents`, `commands`, `hooks`, `rules`, `skills`)
before symlinking. The content of an existing `~/.extra` and files it does not know about are left untouched. Both files only define
functions when sourced; install and reconfigure call them explicitly, and each function reports its own step
and result.

**Claude Code quality gate (`home/.claude/hooks/`).** A multi-file system that runs Pint/PHPStan/Rector/Pest/PHPUnit
against whatever Laravel/PHP project Claude Code is currently editing, using each project's own installed tools
(never installing dependencies itself). The pieces, in call order:

- `support/project-root.sh` resolves the nearest `composer.json` at or above a path without crossing above the Git
  toplevel, so a monorepo with a nested Composer project (e.g. a Laravel app with its own `packages/*` package) is
  handled correctly. `post-edit.sh`, `quality-gate.sh`, and the `quality` function source it rather
  than re-implementing project resolution. Its `canonical_file_path` resolves an edited file's directory to the
  physical path for `post-edit.sh` and `quality-gate.sh`.
- `post-edit.sh` is the `PostToolUse` hook for every `Write`/`Edit` of a `*.php` file or any `composer.json`: it
  runs the `file`-mode check, writes the project's "dirty" marker under
  `${XDG_CONFIG_HOME:-$HOME/.config}/claude-quality/runs`, and reports a failure without blocking the edit.
- `require-evidence.sh` is the `Stop` hook: before Claude finishes a response, it re-runs `quality fast` for every
  dirty project in the current repo and blocks (exit 2) on failure instead of trusting a claimed fix.
- `quality-gate.sh` is the actual dispatcher (`file`/`fast`/`full` modes), detecting installed tools per project and
  recording each run's result.
- The `quality` shell function (`home/.functions`) is the manual entry point (`quality`, `quality full`,
  `quality file <path>`, `quality status`).

Full behavior, the file/fast/full check matrix, and per-project opt-outs (`CLAUDE_QUALITY_DISABLE`,
`CLAUDE_QUALITY_SKIP_TESTS`, `CLAUDE_QUALITY_SKIP_RECTOR` via a project's uncommitted `.claude/settings.local.json`)
are documented in `home/.claude/hooks/README.md`; read it before changing hook behavior instead of re-deriving it
from the scripts.

**Git helpers (`support/git/`).** Each top-level `*.sh` file defines one command function (`branches`, `push`,
`pull`, `nah`, `merge`, `review`, `prune`, `switch`, `sync`, `search`, `compare`) and is sourced by `.zshrc`.
Shared internal pieces sit in `support/git/support/`, which `.zshrc`'s non-recursive `*.sh` loop skips on its own:

- `stash-guard.sh` defines `_git_stash_guard` / `_git_stash_restore`, which stash the working tree aside for an
  operation and then restore it. `merge`, `pull`, `sync`, and `switch` each `source` it. `switch` passes a message
  that tags the stash with its branch and restores or leaves the stash itself instead of calling `_git_stash_restore`.
- `long-lived-branches.sh` holds the develop/main/master/release list that `sync` iterates and `prune` protects.
- `pickaxe-diff.sh` is the diff driver `search` invokes.

`review`, `compare`, `prune`, and the `cchangelog` function all resolve "the default branch" through the
`git default-branch` alias, which runs `home/.config/git/default-branch`. That script tries the live remote HEAD
(`upstream`, then `origin`), then the local remote-tracking cache, then a `main`/`master` probe. It is the single
place that logic lives; callers never re-derive it. Its priority order is covered by `tests/git/default-branch.bats`.

**Tests mirror source layout.**

- `tests/claude/hooks/*.bats`: the quality gate hooks
- `tests/claude/statusline.bats`: context thresholds and input fallbacks in `home/.claude/statusline.sh`
- `tests/claude/skills/*/*.bats`: the bundled scripts of local skills under `home/.claude/skills/`
- `tests/claude/skills/portability.bats`: the skills shared with Codex
- `tests/functions/*.bats`: selected functions from `home/.functions`
- `tests/aliases/*.bats`: selected aliases from `home/.aliases`
- `tests/git/*.bats`: the helpers from `support/git/`
- `tests/shell/startup.bats`: loading `home/.zprofile` and `home/.zshrc` together, command availability,
  and PATH priority and deduplication from `home/.paths`, with external initialization isolated
- `tests/setup/claude/*.bats`, `tests/setup/codex/*.bats`, `tests/setup/packages/*.bats`: the setup/cleanup
  declarations in `support/setup/claude/`, `support/setup/codex/`, and `support/setup/packages/`
- `tests/setup/herd/*.bats`: `support/setup/herd/herd-xdebug.sh` and `support/setup/herd/herd-onboarding.sh`
- `tests/setup/*.bats`: the files directly in `support/setup/`, the profile handling in `support/config/Brewfile`,
  and that sourcing a setup file changes nothing
- `tests/bin/macos-defaults.bats`: `bin/macos-defaults.sh`
- `tests/bin/install.bats`: full `bin/install.sh` orchestration with external setup steps stubbed,
  real directory preparation and links, dependency ordering, repetition, and failure handling
- `tests/bin/update.bats`: a full `bin/update.sh` run across all package cleanups
- `tests/bin/reconfigure.bats`: configuration application without macOS defaults or an unconditional sudo request
- `tests/bin/setup-ssh.bats`: standalone SSH key setup and protection of existing keys
- `tests/bin/test.bats`: interpreter selection, argument forwarding, and failure propagation in `bin/test.sh`
- `tests/support/test-helper.bats`: lossless command argument assertions and fixture cleanup from
  `tests/support/test_helper.bash`

`tests/support/test_helper.bash` provides shared fixtures (`new_dotfiles_fixture`, `call_dotfiles_function`,
`call_dotfiles_function_in`, `call_dotfiles_alias`) for building throwaway Git repos/projects under
`$BATS_TEST_TMPDIR`; most suites also load their own `tests/support/<name>_helper.bash` for suite-specific fixtures.
`tests/support/configuration_helper.bash` holds the independent expected link mapping used by install and
reconfigure tests. `assert_binary_called_with_args` in `tests/support/test_helper.bash` checks NUL-separated
argument records from `write_fake_binary`, preserving empty arguments, whitespace, and literal special characters.
The text call log remains available for output and partial command checks.

Tests assert observable files, Git state, output, exit status, and public command contracts. Do not assert source
spelling, private helper names, arbitrary step ordering, or prose formulations. Static checks are appropriate for
declarative configuration and shared document formats consumed by other tools or skills. At external boundaries
that cannot safely run in tests, check command arguments and failure handling; use real tools with isolated data
when practical. `tests/bin/macos-defaults.bats` records privileged calls without executing them and confines real
PlistBuddy writes to its fixture HOME. These tests do not prove that macOS accepts every declared preference or
that a fresh machine can install every external package.

Read tests as behavior documentation. Each `@test` name identifies the command or process, the relevant condition,
and the expected outcome. Arrange the scenario-specific state in the test; use `setup` for a clearly visible shared
baseline and helpers for mechanical fixture construction. Assertions state the expected values and effects
explicitly. A call count alone does not prove which database was migrated or which file was imported. Put
single-command scenarios in that command's test file
and source-only checks in `tests/setup/sourcing.bats`. Keep cross-component scenarios together with the behavior
they document, such as the edit-to-stop lifecycle or the machine profile shared by the setup entry points.

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
- `home/.claude/AGENTS.md` (see Architecture) is a different file from this one: it applies to every project, not
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
does, what to check before installing, how to install, update, and adapt it, and which commands it adds. This file
explains the architecture to agents, `home/.claude/hooks/README.md` documents the quality gate, and
`home/.claude/AGENTS.md` holds the global instructions for every project, including the skills and tools they name.
Some facts appear in more than one of the four on purpose, so a change can make several of them wrong at once.

- After changing a file, search all four documents for its repository path (and, for a file under `home/`, also
  its `~/` path) and check every match against the new behavior. Update them in the same change.
- When adding something a user runs or invokes (a script under `bin/`, an alias, a function, a Git helper, a skill
  in a Codex allowlist, a declared package), decide whether `README.md` should mention it.
- When a sentence in one of these documents describes what a specific file does, name or link that file, so the
  search above finds the sentence.
- Never leave a line that contradicts the code.
