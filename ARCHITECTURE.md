# Architecture

This document describes the dotfiles setup, update processes, development tools, and their constraints.
Working rules and required checks live in [AGENTS.md](AGENTS.md) and the project rules in
[`.claude/rules/`](.claude/rules/); installation and daily usage are documented
in [README.md](README.md). Read the sections relevant to the subsystem being changed.

The documentation separates a concise agent entry point from detailed reference material, following the
[OpenAI harness engineering report](https://openai.com/index/harness-engineering/#we-made-repository-knowledge-the-system-of-record).
A link is a reading instruction, not an automatic import: agents must open the relevant section before relying
on it. The source files and tests named here provide the evidence for each subsystem's behavior.

## Contents

- [Setup entry points](#setup-entry-points)
- [Home directory preparation](#home-directory-preparation)
- [Update cooldown](#update-cooldown)
- [Quality gate](#quality-gate)
- [Git helpers](#git-helpers)
- [Test layout and fixtures](#test-layout-and-fixtures)
- [Verification tooling](#verification-tooling)

## Setup entry points

**Entry points vs. setup logic.** Files in `support/setup/` define variables and functions; sourcing them does
not run setup. Calling one of those functions with the real `HOME` and `PATH` does: it installs, updates, or removes
real packages, skills, and plugins. To find out what a function does, read it or call it through the test fixtures
(fixture `HOME`, `given_fake_bin_on_path`). Each script under `bin/` sources every setup file it uses in one block
after `set -e`, always from `~/.dotfiles`, the fixed location the symlinks and aliases already depend on. It then
calls those functions
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

## Home directory preparation

**`support/setup/home-directories.sh` prepares directories and clears paths for symlinks.** Its `prepare_home_directories`
creates `~/Screenshots`, `~/Temp`, `~/Code`, `~/.config/ghostty`, `~/.config/git`, `~/.claude`, and `~/.codex`,
and an empty `~/.extra` when none exists.
`support/setup/dotfile-links.sh` defines `link_dotfiles`, which uses `ln -sf`/`ln -sfn` for every
managed path. Those commands already replace an existing file or symlink, but cannot replace a real directory,
so `prepare_home_directories` clears the five `~/.claude/` paths (`agents`, `commands`, `hooks`, `rules`, `skills`)
before symlinking. The content of an existing `~/.extra` and files it does not know about are left untouched. Both files only define
functions when sourced; install and reconfigure call them explicitly, and each function reports its own step
and result.

## Update cooldown

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

## Quality gate

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

## Git helpers

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

## Test layout and fixtures

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
- `tests/bin/test.bats`: interpreter selection, argument forwarding, failure propagation, and signal cancellation
  in `bin/test.sh`
- `tests/support/test-helper.bats`: lossless command argument assertions and fixture cleanup from
  `tests/support/test_helper.bash`

`tests/support/test_helper.bash` provides shared fixtures (`new_dotfiles_fixture`, `call_dotfiles_function`,
`call_dotfiles_function_in`, `call_dotfiles_alias`) for building throwaway Git repos/projects under
`$BATS_TEST_TMPDIR`; most suites also load their own `tests/support/<name>_helper.bash` for suite-specific fixtures.
`tests/support/configuration_helper.bash` holds the independent expected link mapping used by install and
reconfigure tests. `assert_binary_called_with_args` in `tests/support/test_helper.bash` checks NUL-separated
argument records from `write_fake_binary`, preserving empty arguments, whitespace, and literal special characters.
The text call log remains available for output and partial command checks.

## Verification tooling

`bin/test.sh` runs the files concurrently via `bats --jobs`, because the suite is almost entirely process-spawn
wait rather than CPU. The parallel backend is `rush` (Brewfile: `rush-parallel`, already a dependency) rather than
GNU `parallel`, selected with `--parallel-binary-name`. Job count defaults to the core count; set `BATS_JOBS=1` to
run serially when debugging a test that only fails under concurrency. Fixtures keep all mutable state under
`$BATS_TEST_TMPDIR`, so tests are order-independent and safe to parallelize.

`bin/test.sh` prepends `support/test-shell/` to PATH. Its tracked `bash` symlink targets `/bin/bash`, keeping Bats
and its subprocesses, including fake executables, on macOS Bash 3.2 even when Homebrew's Bash is installed.
The runner uses `exec` to replace itself with Bats, so signals sent to the runner PID reach Bats directly.

A quiet start followed by bursts of output is not a hang. Most of the wall time is macOS `syspolicyd` assessing each
freshly written fake-binary stub (`write_fake_binary` in `tests/support/test_helper.bash`) on its first exec. That
check is serial and cannot be skipped, so more jobs do not shorten it. Cutting it would mean creating the stubs once
per file instead of once per test.

The style lives in `.editorconfig`, because shfmt ignores it as soon as a style flag is passed on the command line:
4-space indent plus `-ci -bn`, the options shfmt's documentation names for Google's Shell Style Guide.
`bin/format.sh` passes only tracked files, adds the zsh dotfiles by name because shfmt does not detect them, and
leaves out `home/.zshrc` and `home/.zprofile` (Herd and Docker Desktop write into them) and the third-party skills
under `home/.claude/skills/`, which update reinstalls from upstream. Adding a third-party skill to `THIRD_PARTY_SKILLS`
in `support/setup/claude/claude-skills.sh` means adding it to the ignore list in `.editorconfig` too.

CI (`.github/workflows/tests.yml`) runs `bin/test.sh` on `macos-latest`, matching the interpreter and userland
(`/bin/bash` 3.2, BSD tools) the target machine actually has, with `bats-core`, `php`, `patchutils`, and
`rush-parallel` installed via Homebrew. The Python 3 that the `bin/test.sh` signal tests use comes preinstalled with the
runner image. `.github/workflows/lint.yml` runs `bin/format.sh --check` with Homebrew's
`shfmt` as its own workflow, so a formatting failure never hides a test result. Each workflow file, its `name`, and
its single job share one name (`tests`, `lint`). The `main` ruleset requires both checks by job name; renaming a
job means updating the ruleset in the same change.

There is no build step and no static analysis. Bash and zsh get the same checks, formatting and tests: ShellCheck
covers only Bash, and no zsh linter is mature enough to depend on, so neither language gets one.
