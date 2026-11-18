#!/bin/bash

# A new upstream version of a plugin or skill is installed only after update.sh has seen it
# unchanged this long, the same 3 days Composer and npm wait for a release. Neither Claude Code nor
# the skills CLI has a cooldown of its own, and both install whatever is upstream, so the time
# counts from update.sh's first sighting, not from the commit date, which the author sets.
UPDATE_COOLDOWN_DAYS=3
UPDATE_COOLDOWN_FIRST_SEEN="${XDG_CONFIG_HOME:-$HOME/.config}/claude-update-cooldown/first-seen"

# Succeeds when upstream <state> of <id> has been seen unchanged for the cooldown. A state not seen
# before is recorded as first seen now, replacing the previous one, so the cooldown starts again.
has_cooled_down() {
    local id="$1" state="$2" now seen
    now="$(date +%s)"
    seen="$(awk -F '\t' -v id="$id" -v state="$state" '$1 == id && $2 == state { print $3 }' \
        "$UPDATE_COOLDOWN_FIRST_SEEN" 2>/dev/null)"
    # Shell arithmetic reads a word as 0, which would end the cooldown, so only digits count.
    case "$seen" in
        '' | *[!0-9]*)
            mkdir -p "$(dirname "$UPDATE_COOLDOWN_FIRST_SEEN")"
            {
                awk -F '\t' -v id="$id" '$1 != id' "$UPDATE_COOLDOWN_FIRST_SEEN" 2>/dev/null
                printf '%s\t%s\t%s\n' "$id" "$state" "$now"
            } >"$UPDATE_COOLDOWN_FIRST_SEEN.tmp" && mv "$UPDATE_COOLDOWN_FIRST_SEEN.tmp" "$UPDATE_COOLDOWN_FIRST_SEEN"
            return 1
            ;;
    esac
    ((now - seen >= UPDATE_COOLDOWN_DAYS * 86400))
}

# Raises a pinned npm package to its newest stable release that is at least 3 days old, the same
# cooldown its npx call enforces. The raised pin is an uncommitted change in this repository and
# takes effect on the next run, which refuses a dirty worktree, so it is committed first. Calls
# global_npm from support/setup/packages/npm-packages.sh.
raise_npm_pin() {
    local package="$1" file="$2" variable="$3"
    local current newest
    current="$(sed -n "s/^$variable=\"\(.*\)\"$/\1/p" "$file")"
    # pipefail, so a failed npm lookup is reported instead of reading as "no newer release".
    # npm 12 wraps `npm view --json` output in an array, hence the leading .[0].
    if ! newest="$(
        set -o pipefail
        global_npm view "$package" time --json 2>/dev/null \
            | jq -r --arg current "$current" '
            def numbers: split(".") | map(tonumber);
            .[0]
            | to_entries
            | map(select(.key | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")))
            | map(select((.value | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) <= now - 3 * 86400))
            | map(select((.key | numbers) > ($current | numbers)))
            | max_by(.key | numbers) | .key // empty'
    )"; then
        warn "Could not check $package for a newer release"
        return 0
    fi
    [[ -n "$newest" ]] || return 0

    if ! sed -i '' "s/^$variable=\"$current\"$/$variable=\"$newest\"/" "$file"; then
        warn "Could not raise $package from $current to $newest in ${file#"$HOME/"}"
        return 0
    fi
    note "Raised $package from $current to $newest in ${file#"$HOME/"}. Release notes: https://www.npmjs.com/package/$package/v/$newest. Commit the change before the next update."
}

raise_npm_pins() {
    step "Checking pinned npm packages"
    raise_npm_pin chrome-devtools-mcp ~/.dotfiles/support/setup/claude/claude-plugins.sh CHROME_DEVTOOLS_MCP_VERSION
    raise_npm_pin skills ~/.dotfiles/support/setup/claude/claude-skills.sh SKILLS_CLI_VERSION
}
