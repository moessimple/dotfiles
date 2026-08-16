# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Personal, opinionated dotfiles for Laravel/PHP development on macOS (Herd, Oh My Zsh, modern CLI tools, a
version-controlled Claude Code configuration). There is no build step and no application code; changes take effect
by symlinking files into `$HOME` and by shell scripts that install/configure the machine.

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

CI (`.github/workflows/tests.yml`) runs the same `bats -r tests/` on Ubuntu with `bats`, `php-cli`, and `zsh`
installed; no macOS-only behavior is exercised there.

There is no separate lint/build command; shell code is not linted automatically in this repo.

## Architecture

**`home/` mirrors `$HOME`.** Every file under `home/` is symlinked to the same relative path below `$HOME` (e.g.
`home/.zshrc` → `~/.zshrc`, `home/.claude/skills` → `~/.claude/skills`). Editing the path in either location changes
the file tracked in this repository. `support/setup/symlink-dotfiles.sh` is the single source of truth for which
paths are linked and whether a given path is linked as a file (`ln -sf`) or as a directory (`ln -sfn`, used for
`.claude/agents`, `.claude/commands`, `.claude/hooks`, `.claude/rules`, `.claude/skills`).

`~/.codex/AGENTS.md` intentionally links to `~/.claude/CLAUDE.md`, so Claude Code and the lightweight Codex fallback
share one global instruction file instead of maintaining two copies.

**Entry points vs. setup logic.** `bin/install.sh`, `bin/reconfigure.sh`, and `bin/update.sh` are the only scripts a
user runs directly; each sources scripts under `support/setup/` in a specific order (documented by comments at each
`source` call in the entry-point scripts) rather than duplicating logic. `install.sh` does a full fresh setup
(Homebrew, Oh My Zsh, symlinks, packages, Herd, tinkerbench, macOS defaults). `reconfigure.sh` reapplies symlinks,
service setup, Herd/tinkerbench, and macOS defaults without touching package managers. `update.sh` pulls the repo,
then updates Homebrew, global Composer/npm packages, and Claude Code skills/plugins.

**Declared list = desired state.** The Brewfile (`support/config/Brewfile`), global Composer/npm package lists
(`support/setup/packages/`), and Claude Code skills/plugins (`support/setup/claude/claude-skills.sh`,
`claude-plugins.sh`) are each treated as the full desired state. `bin/update.sh` calls a `*_cleanup` function after
each update step that removes anything installed but not declared in that file. When adding a package or skill,
add it to the declaration; do not install it out of band, or the next `update.sh` run removes it. `claude-skills.sh`
documents a manual vetting checklist to run before adding any third-party skill.

**`support/setup/clean-state.sh` clears what `ln -sf` itself cannot replace.** `symlink-dotfiles.sh` uses `ln -sf`/
`ln -sfn` for every managed path, which already replaces an existing file or symlink on its own. The one case it
cannot handle is a real (non-symlink) directory, so `clean-state.sh` only clears the five `~/.claude/` directories
(`agents`, `commands`, `hooks`, `rules`, `skills`) before symlinking. Files it does not know about (e.g. `~/.extra`)
are left untouched.

**Claude Code quality gate (`home/.claude/hooks/`).** A multi-file system that runs Pint/PHPStan/Rector/Pest/PHPUnit
against the Laravel/PHP repository Claude Code is currently editing, using the repository's own installed tools
(never installing dependencies itself). The pieces, in call order:

- `support/project-root.sh` accepts a Git repository as a project only when `composer.json` exists at its toplevel.
  Both other hooks source this file rather than re-implementing project resolution.
- `post-php-edit.sh` / `post-composer-edit.sh` are `PostToolUse` hooks that run a `file`-mode check after every
  `Write`/`Edit` and leave a "dirty" marker for the project under
  `${XDG_CONFIG_HOME:-$HOME/.config}/claude-quality/runs`.
- `require-evidence.sh` is the `Stop` hook: before Claude finishes a response, it re-runs `quality fast` for the
  current repository when dirty and blocks (exit 2) on failure instead of trusting a claimed fix.
- `quality-gate.sh` is the actual dispatcher (`file`/`fast`/`full` modes), detecting installed tools per project and
  recording each run's result.
- The `quality` shell function (`home/.functions`) is the manual entry point (`quality`, `quality full`,
  `quality file <path>`, `quality status`).

Full behavior, the file/fast/full check matrix, and per-project opt-outs (`CLAUDE_QUALITY_DISABLE`,
`CLAUDE_QUALITY_SKIP_TESTS`, `CLAUDE_QUALITY_SKIP_RECTOR` via a project's uncommitted `.claude/settings.local.json`)
are documented in `home/.claude/hooks/README.md`; read it before changing hook behavior instead of re-deriving it
from the scripts.

**Git helpers (`support/git/`).** Each `*.sh` file defines one function (`branches`, `push`, `pull`, `nah`, `merge`,
`review`, `prune`, `switch`, `sync`, `search`, `check`) and is sourced individually by `.zshrc`. `pickaxe-diff.sh`
is an exception: it is a diff driver invoked by `search`, not sourced at shell startup, and `.zshrc` explicitly
skips it in its sourcing loop.

**Tests mirror source layout.** `tests/claude/hooks/*.bats` covers the quality gate hooks; `tests/functions/*.bats`
covers selected functions from `home/.functions`; `tests/git/*.bats` covers the helpers from `support/git/`.
`tests/support/test_helper.bash` provides shared fixtures (`new_dotfiles_fixture`, `new_git_function_fixture`) for
building throwaway Git repos/projects under `mktemp -d`.

## Conventions specific to this repo

- Machine-specific or secret shell configuration goes in `~/.extra` (sourced by `.zshrc`, never committed), not in
  any file under `home/`.
- `home/.claude/CLAUDE.md` is the user-level Claude Code instructions file (symlinked to `~/.claude/CLAUDE.md`); it
  is a different file from this one and applies globally across all projects, not just this repo.
