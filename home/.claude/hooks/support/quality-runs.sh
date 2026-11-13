#!/usr/bin/env bash
#
# Where quality-gate.sh records a Composer project's last fast or full run
# (<root>.json) and post-edit.sh marks the project as changed since then
# (<root>.dirty). <root> is the project's absolute path, so each project's
# files sit at that same path below this directory.

quality_runs_dir="${XDG_CONFIG_HOME:-$HOME/.config}/claude-quality/runs"
