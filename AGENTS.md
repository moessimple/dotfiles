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
`bin/update.sh` have different scopes, documented below. Gaps in synchronization are implementation limitations,
not exceptions to the goal or reasons to preserve drift. Only reconcile explicitly managed
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

A quiet start followed by bursts of output is not a hang. Most of the wall time is macOS `syspolicyd` assessing each
freshly written fake-binary stub (`write_fake_binary` in `tests/support/test_helper.bash`) on its first exec. That
check is serial and cannot be skipped, so more jobs do not shorten it. Cutting it would mean creating the stubs once
per file instead of once per test.

CI (`.github/workflows/tests.yml`) runs `bin/test.sh` on `macos-latest`, matching the interpreter and userland
(`/bin/bash` 3.2, BSD tools) the target machine actually has, with `bats-core`, `php`, `patchutils`, and
`rush-parallel` installed via Homebrew.

There is no separate lint/build command; shell code is not linted automatically in this repo.

## Architecture

**`home/` mirrors `$HOME`.** Every file under `home/` except `home/.claude/AGENTS.md` (see below) is symlinked to the
same relative path below `$HOME` (e.g. `home/.zshrc` → `~/.zshrc`, `home/.claude/skills` → `~/.claude/skills`).
Editing the path in either location changes the file tracked in this repository.
`support/setup/symlink-dotfiles.sh` is the single source of truth for which paths are linked and whether a given path
is linked as a file (`ln -sf`) or as a directory (`ln -sfn`, used for `.claude/agents`, `.claude/commands`,
`.claude/hooks`, `.claude/rules`, `.claude/skills`).

`home/.claude/AGENTS.md` holds the global instructions and is the one exception to the mirror: `symlink-dotfiles.sh`
links it as `~/.claude/CLAUDE.md`, the only name Claude Code reads user-level instructions from, and as
`~/.codex/AGENTS.md` for Codex, so both share one file instead of two copies. A Claude Code session started in
`home/` also reads `home/.claude/AGENTS.md` as project instructions and so loads the global instructions twice;
start sessions in the repository root.
`support/setup/codex/codex-skills.sh` links explicitly reviewed harness-neutral skills from `home/.claude/skills/` and
Claude's installed plugin cache into `~/.agents/skills`.
Claude remains the only installer and updater. Shared workflows keep their instructions in one `SKILL.md`. Skills
with agent-specific tools, paths, or runtime behavior stay exclusive to that agent.

**Entry points vs. setup logic.** `bin/install.sh`, `bin/reconfigure.sh`, and `bin/update.sh` are the setup scripts a
user runs directly (besides `bin/test.sh` and the standalone `bin/setup-ssh.sh`); each sources scripts under
`support/setup/` in a specific order (documented by comments at each `source` call in the entry-point scripts)
rather than duplicating logic. `install.sh`
does a full fresh setup (Homebrew, Oh My Zsh, symlinks, packages, Herd, tinkerbench, macOS defaults).
`reconfigure.sh` reapplies symlinks, Codex skill links, service setup, Herd/tinkerbench, and macOS defaults without
touching package managers. `update.sh` pulls the repo, then updates Homebrew, global Composer/npm packages,
user-level Python packages, Claude Code skills/plugins (after a cooldown, see below), Codex skill links, and
Ollama models.

`bin/setup-ssh.sh` runs before cloning on a fresh Mac. It generates an Ed25519 key, adds it to the SSH agent and
macOS Keychain, and copies the public key for manual registration on GitHub. It refuses to overwrite existing keys
and does not run as part of `bin/install.sh`.

`bin/install.sh`, `bin/reconfigure.sh`, and `bin/update.sh` read and validate the saved profile through
`support/setup/machine-profile.sh`. On its first run, `bin/install.sh` asks private/work,
saves the choice in `~/.config/dotfiles/profile`, and asks for the machine's Git email for either profile.
Private setup offers the existing global email as a default. Only `user.email` is written to the untracked
`~/.gitconfig-local`, which `home/.gitconfig` includes last; the name stays shared. `home/.gitconfig` has no email
fallback and sets `user.useConfigOnly = true`, so Git refuses commits without a configured email.
Later installs reuse the profile and ask only for the email if the local setting is missing or blank.
All profile selection and email setup logic lives directly in `bin/install.sh`. Reconfigure and update never
prompt and default to private without a saved profile. `support/config/Brewfile`
reads the same profile and excludes Discord and WhatsApp on work machines, including from the desired state
used by update's cleanup. Other packages and sudo steps are shared.

**Claude Code plugin and skill updates (`support/setup/claude/update-cooldown.sh`).** Neither Claude Code nor the
skills CLI has a release-age cooldown, so `update.sh` calls `update_skills_after_cooldown` and
`update_plugins_after_cooldown`, which give them the same 3 days that Composer and npm wait. The upstream state (a
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
`claude-plugins.sh`), and Codex-compatible skills (`support/setup/codex/codex-skills.sh`) are each treated as the full
desired state. After each update step, `bin/update.sh` removes anything installed but not declared: Homebrew via
`brew bundle cleanup --force`, the others via a `*_cleanup` function in the declaring file, while `codex-skills.sh`
prunes its own stale links on every run. When adding a package or skill, add it to the declaration; do not
install it out of band, or the next `update.sh` run removes it. `claude-skills.sh` documents a manual vetting checklist
to run before adding any third-party skill. Add a source to `CODEX_COMPATIBLE_SKILLS` or
`CODEX_COMPATIBLE_CLAUDE_PLUGIN_SKILLS` only after confirming that its full directory is harness-neutral and does not
duplicate a Codex skill.

**`support/setup/clean-state.sh` clears what `ln -sf` itself cannot replace.** `symlink-dotfiles.sh` uses `ln -sf`/
`ln -sfn` for every managed path, which already replaces an existing file or symlink on its own. The one case it
cannot handle is a real (non-symlink) directory, so `clean-state.sh` only clears the five `~/.claude/` directories
(`agents`, `commands`, `hooks`, `rules`, `skills`) before symlinking. Files it does not know about (e.g. `~/.extra`)
are left untouched.

**Claude Code quality gate (`home/.claude/hooks/`).** A multi-file system that runs Pint/PHPStan/Rector/Pest/PHPUnit
against whatever Laravel/PHP project Claude Code is currently editing, using each project's own installed tools
(never installing dependencies itself). The pieces, in call order:

- `support/project-root.sh` resolves the nearest `composer.json` at or above a path without crossing above the Git
  toplevel, so a monorepo with a nested Composer project (e.g. a Laravel app with its own `packages/*` package) is
  handled correctly. `post-edit.sh`, `quality-gate.sh`, and the `quality` function source it rather
  than re-implementing project resolution.
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
- `tests/claude/skills/*/*.bats`: the bundled scripts of local skills under `home/.claude/skills/`
- `tests/claude/skills/portability.bats`: the skills shared with Codex
- `tests/functions/*.bats`: selected functions from `home/.functions`
- `tests/aliases/*.bats`: selected aliases from `home/.aliases`
- `tests/git/*.bats`: the helpers from `support/git/`
- `tests/setup/claude/*.bats`, `tests/setup/codex/*.bats`, `tests/setup/packages/*.bats`: the setup/cleanup
  declarations in `support/setup/claude/`, `support/setup/codex/`, and `support/setup/packages/`
- `tests/setup/herd/*.bats`: `support/setup/herd-debug-ini.sh`
- `tests/setup/macos/*.bats`: `support/setup/macos/osx-defaults.sh`
- `tests/bin/update.bats`: a full `bin/update.sh` run across all package cleanups
- `tests/bin/setup-ssh.bats`: standalone SSH key setup and protection of existing keys

`tests/support/test_helper.bash` provides shared fixtures (`new_dotfiles_fixture`, `call_dotfiles_function`,
`call_dotfiles_function_in`, `call_dotfiles_alias`) for building throwaway Git repos/projects under
`$BATS_TEST_TMPDIR`; most suites also load their own `tests/support/<name>_helper.bash` for suite-specific fixtures.

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
