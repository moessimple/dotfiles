# Quality Gate Hooks

These Claude Code hooks run the available quality tools for a PHP or Laravel project after relevant edits and before
Claude finishes a response. They reuse the project's installed tools and configuration; they do not install project
dependencies or provide Pint, PHPStan, Rector, Pest, PHPUnit, or ParaTest themselves.

See the [root README](../../../README.md) for installation and the wider dotfiles setup.

## Why This Exists

A coding agent can be instructed to run quality checks, but an instruction is not evidence that they ran or passed.
Claude Code [hooks](https://code.claude.com/docs/en/hooks) provide deterministic lifecycle checkpoints instead of
depending on the model to remember them.

This gate uses two feedback loops: inexpensive file checks after supported edits, then a project check before Claude
stops for a Composer project marked by those edits. Both loops run the project's installed tools and configuration,
which remain the source of truth.

A passing gate is evidence that the configured checks succeeded, not proof that the change is correct. Local hooks
complement review and CI; authoritative merge protection should use server-side
[required status checks](https://docs.github.com/repositories/configuring-branches-and-merges/managing-protected-branches/about-protected-branches#require-status-checks-before-merging).

Command hooks execute project code with the local user's permissions. Use them only in trusted repositories; see the
official [security considerations](https://code.claude.com/docs/en/hooks#security-considerations).

## Requirements and Activation

The dotfiles installer symlinks this directory to `~/.claude/hooks` and
[`home/.claude/settings.json`](../settings.json) registers two `PostToolUse` hooks and one `Stop` hook. The `quality`
shell command comes from [`home/.functions`](../../.functions), which `.zshrc` loads for interactive shells.

A checked project must:

- be inside a Git repository;
- contain a `composer.json` at the Git repository root; and
- have at least one supported project tool, an `artisan` file, or a global `composer` command.

The hook scripts also use Bash, Git, and `jq`. The full dotfiles installer provides the global commands, but
the project's own Composer dependencies remain the project's responsibility.

## Checks and Modes

The dispatcher detects executable tools under the project's `vendor/bin/`. Tests prefer Pest, then PHPUnit, then
`artisan test`. When `vendor/bin/paratest` exists, Pest and `artisan test` receive `--parallel`; for a plain PHPUnit
project, ParaTest runs instead of PHPUnit.

| Check                            | `file`                 | `fast`                                           | `full`               |
| -------------------------------- | ---------------------- | ------------------------------------------------ | -------------------- |
| Pint                             | Edited PHP file        | PHP files with uncommitted changes via `--dirty` | Whole project        |
| Rector                           | Edited PHP file        | PHP files with uncommitted changes               | Whole project        |
| PHPStan                          | —                      | Whole project                                    | Whole project        |
| `composer validate`              | Edited `composer.json` | Project manifest                                 | Project manifest     |
| `composer audit`                 | —                      | —                                                | Project dependencies |
| Pest, PHPUnit, or `artisan test` | —                      | Full test suite                                  | Full test suite      |

`file` mode ignores unrelated files. It also skips PHP files under dot-directories because project-wide Pint and Rector
runs do not normally cover them. Pint is skipped when the path matches the project's `pint.json` `exclude` or
`notPath` configuration; Rector still runs unless it is disabled with the flag described below.

`fast` limits Pint and Rector to staged, unstaged, and untracked PHP files. PHPStan and the test suite still run for the
whole project because this gate has no reliable way to map one changed file to only the affected analysis or tests.

`full` is the manual, whole-project check. It also runs `composer audit` and ignores the automatic Rector and test
skip flags.

## Automatic Flow

### After an Edit

Claude Code invokes both `PostToolUse` hooks after every `Write` or `Edit` operation:

- [`post-php-edit.sh`](post-php-edit.sh) accepts existing `.php` files and runs `file` mode.
- [`post-composer-edit.sh`](post-composer-edit.sh) accepts files named `composer.json` and runs
  `composer validate` through `file` mode.

Each hook resolves the surrounding Git repository and requires its `composer.json` at the repository root. When
supported tooling is found, it creates a dirty marker for that project even if the immediate file check passes. A
failing check returns its output to Claude so the next action can address it. Because these are post-edit hooks, they
report problems but cannot undo the edit.

### Before Claude Stops

[`require-evidence.sh`](require-evidence.sh) runs whenever Claude tries to finish a response. If the current Git
repository has a dirty marker, it runs `quality fast`. A passing run clears the marker. A failing run leaves it in
place, returns the tool output, and blocks the response with exit code 2.

This implementation deliberately reruns the real gate on every subsequent stop attempt instead of accepting a claim
that the failure was fixed. Claude Code overrides a Stop hook after eight consecutive blocks without progress; the
limit can be changed with `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`. A failing project's marker remains after the cap, so it is
checked again on a later Stop event. See Claude Code's official
[hook troubleshooting documentation](https://code.claude.com/docs/en/hooks-guide#stop-hook-hits-the-block-cap).

The configured timeout is 60 seconds for each post-edit hook and 120 seconds for the Stop hook. A project whose fast
gate takes longer can exceed the automatic hook timeout; the manual `quality` command is not subject to those Claude
Code hook timeouts.

## Project Opt-Outs

Claude Code combines hooks from every applicable settings file. A project-level hook does not replace this user-level
hook, so a project with an equivalent gate may otherwise run the same tools twice.

Set any opt-out in the project's uncommitted `.claude/settings.local.json` under `env`:

```json
{
  "env": {
    "CLAUDE_QUALITY_SKIP_TESTS": "1"
  }
}
```

- `CLAUDE_QUALITY_DISABLE=1` disables the post-edit gate for that project. No dirty marker is created, so the Stop hook
  has nothing to run for those edits.
- `CLAUDE_QUALITY_SKIP_TESTS=1` skips the test suite in automatic `fast` runs.
- `CLAUDE_QUALITY_SKIP_RECTOR=1` skips Rector in automatic `file` and `fast` runs.

Manual `quality full` runs ignore the last two flags. For pre-existing PHPStan findings, use the project's own PHPStan
baseline rather than disabling another check.

## Manual Usage

Run these commands inside a Git-backed Composer project:

- `quality` or `quality fast` runs the same mode used by the Stop hook.
- `quality full` runs all available whole-project checks.
- `quality file <path>` runs the eligible file-level checks for one PHP file or `composer.json`.
- `quality status` prints the most recent recorded `fast` or `full` result and reports whether the project has since
  been marked dirty.

If no Composer project or supported tooling is found, the dispatcher reports that there is nothing to check and exits
with status 3. That condition does not block Claude from stopping. A `fast` run clears a marker when the project still
exists but has lost all supported tooling. If its `composer.json` was removed entirely, the stale marker is ignored but
remains on disk and may be reconsidered by later Stop events.

## State Files

`fast` and `full` write their last result below `${XDG_CONFIG_HOME:-$HOME/.config}/claude-quality/runs`, keyed by the
project's absolute path. The JSON record contains the project root, mode, Git commit, worktree state, exit code, and a
UTC timestamp. A sibling `.dirty` marker records that a relevant edit has not yet been followed by a passing gate.

The Stop hook considers only the marker for the current Git repository.

## Implementation and Tests

| File                                                     | Role                                                               |
| -------------------------------------------------------- | ------------------------------------------------------------------ |
| [`post-php-edit.sh`](post-php-edit.sh)                   | Matches PHP edits and starts the file gate                         |
| [`post-composer-edit.sh`](post-composer-edit.sh)         | Matches `composer.json` edits and starts validation                |
| [`require-evidence.sh`](require-evidence.sh)             | Runs `fast` for the dirty repository and blocks on failure         |
| [`quality-gate.sh`](quality-gate.sh)                     | Resolves modes, detects tools, runs checks, and records results    |
| [`support/post-edit-gate.sh`](support/post-edit-gate.sh) | Shares post-edit execution, marker, and reporting logic            |
| [`support/project-root.sh`](support/project-root.sh)     | Requires a root Composer manifest and resolves the Git repository  |
| [`tests/claude/hooks/`](../../../tests/claude/hooks/)    | Bats coverage for each hook, the dispatcher, and their integration |

Run the hook tests from the dotfiles root:

```zsh
bats -r tests/
```
