#!/bin/bash

input=$(cat)

# Pull the directory and the whole-number context percentage in one pass.
IFS=$'\t' read -r cwd ctx_pct < <(
  jq -r '[.workspace.current_dir, ((.context_window.used_percentage // 0) | floor)] | @tsv' <<< "$input"
)

if [ "$ctx_pct" -ge 60 ]; then
  ctx_color='\033[01;31m' # red
elif [ "$ctx_pct" -ge 40 ]; then
  ctx_color='\033[01;33m' # yellow
else
  ctx_color='\033[01;32m' # green
fi

printf '\033[01;36m%s\033[00m | ctx: %b%s%%\033[00m' \
  "$(basename "$cwd")" "$ctx_color" "$ctx_pct"
