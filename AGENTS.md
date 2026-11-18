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
| Git helpers (`support/git/`), the loop in `home/.zshrc` that sources them, Git configuration, or Git-related functions in `home/.functions` | [Git helpers](ARCHITECTURE.md#git-helpers) |
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
install it out of band, or the next `update.sh` run removes it. Follow the review checklist in
[`.claude/skills/review-third-party-skill/SKILL.md`](.claude/skills/review-third-party-skill/SKILL.md) before
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

## Shell and test conventions

The repository's shell conventions live in [`.claude/rules/shell.md`](.claude/rules/shell.md) and its test
conventions in [`.claude/rules/tests.md`](.claude/rules/tests.md). Before writing or changing a file, read every
rule in `.claude/rules/` whose `paths:` frontmatter matches it. Claude Code also loads a matching rule on its own
when it reads or edits the file; Codex does not. These project rules apply only to this repository and are not
linked into `$HOME`; `home/.claude/rules/` holds the global rules for every project.

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
The project rules in `.claude/rules/` and the project skills in `.claude/skills/` hold conventions and procedures
for this repository. Some facts appear in more than one of these documents on purpose, so a change can make several
of them wrong at once.

- After changing a file, search these five documents, `.claude/rules/`, and `.claude/skills/` for its repository
  path (and, for a file under `home/`, also its `~/` path) and check every match against the new behavior. Update
  them in the same change.
- When adding something a user runs or invokes (a script under `bin/`, an alias, a function, a Git helper, a skill
  in a Codex allowlist, a declared package), decide whether `README.md` should mention it.
- When a sentence in one of these documents describes what a specific file does, name or link that file, so the
  search above finds the sentence.
- Never leave a line that contradicts the code.
