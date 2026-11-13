#!/bin/bash

# Sourced after claude-skills.sh (skills_cli, SKILL_LOCK_FILE) and claude-plugins.sh (CLAUDE_PLUGINS).

# A new upstream version of a plugin or skill is installed only after update.sh has seen it
# unchanged this long, the same 3 days Composer and npm wait for a release. Neither Claude Code nor
# the skills CLI has a cooldown of its own, and both install whatever is upstream, so the time
# counts from update.sh's first sighting, not from the commit date, which the author sets.
UPDATE_COOLDOWN_DAYS=3
UPDATE_COOLDOWN_FIRST_SEEN="${XDG_CONFIG_HOME:-$HOME/.config}/claude-update-cooldown/first-seen"

# Succeeds when upstream <state> of <id> has been seen unchanged for the cooldown. A state not seen
# before is recorded as first seen now, replacing the previous one, so the cooldown starts again.
cooled_down() {
    local id="$1" state="$2" now seen
    now=$(date +%s)
    seen=$(awk -F '\t' -v id="$id" -v state="$state" '$1 == id && $2 == state { print $3 }' \
        "$UPDATE_COOLDOWN_FIRST_SEEN" 2>/dev/null)
    # Shell arithmetic reads a word as 0, which would end the cooldown, so only digits count.
    case "$seen" in
        '' | *[!0-9]*)
            mkdir -p "$(dirname "$UPDATE_COOLDOWN_FIRST_SEEN")"
            { awk -F '\t' -v id="$id" '$1 != id' "$UPDATE_COOLDOWN_FIRST_SEEN" 2>/dev/null
                printf '%s\t%s\t%s\n' "$id" "$state" "$now"
            } > "$UPDATE_COOLDOWN_FIRST_SEEN.tmp" && mv "$UPDATE_COOLDOWN_FIRST_SEEN.tmp" "$UPDATE_COOLDOWN_FIRST_SEEN"
            return 1
            ;;
    esac
    [ $(( now - seen )) -ge $(( UPDATE_COOLDOWN_DAYS * 86400 )) ]
}

# Prints the upstream state of plugin <name> in the marketplace <checkout> of <url>: the tree of its
# folder plus its marketplace entry, which can define hooks and servers itself. A source object
# naming the marketplace's own repository is its root. Fails when the plugin is not listed or its
# source is another repository, whose changes this checkout cannot see.
plugin_state() {
    local name="$1" checkout="$2" url="$3" entry source folder slug="" tree
    entry=$(git -C "$checkout" show HEAD:.claude-plugin/marketplace.json 2>/dev/null \
        | jq -ce --arg name "$name" 'first(.plugins[] | select(.name == $name))') || return 1
    source=$(jq -c '.source' <<< "$entry")
    case "$url" in
        https://github.com/*) slug=${url#https://github.com/} && slug=${slug%.git} ;;
    esac
    if folder=$(jq -er 'strings' <<< "$source"); then
        folder=${folder#./}
        folder=${folder%/}
        [ "$folder" != . ] || folder=""
    elif jq -e --arg url "${url%.git}" --arg slug "$slug" \
        '(.repo // "") == $slug and $slug != "" or ((.url // "") | sub("\\.git$"; "")) == $url' \
        <<< "$source" >/dev/null; then
        folder=""
    else
        return 1
    fi
    tree=$(git -C "$checkout" rev-parse --verify --quiet "HEAD:$folder") || return 1
    echo "$tree+$(printf '%s' "$entry" | git hash-object --stdin)"
}

# Updates the plugins in CLAUDE_PLUGINS (claude-plugins.sh) of each marketplace once the upstream
# states of all of them have passed the cooldown. Claude Code itself decides whether that is a new
# version, so an unchanged plugin stays as it is. autoUpdate is off in settings.json, so the
# marketplace is refreshed first.
update_plugins_after_cooldown() {
    local marketplaces
    # pipefail, so a failed listing is reported instead of reading as "no marketplaces to check".
    if ! marketplaces=$(set -o pipefail; claude plugin marketplace list --json 2>/dev/null \
        | jq -r '.[] | select(.url != null) | [.name, .url] | @tsv'); then
        warn "Could not list the plugin marketplaces, plugins not updated"
        return 0
    fi

    local name url checkout plugin state plugins all_cooled_down
    # The list arrives on fd 3, so the claude calls in the loop cannot consume it from stdin.
    while IFS=$'\t' read -r -u 3 name url; do
        [ -n "$name" ] || continue
        checkout=$(mktemp -d)
        if ! git clone --quiet --filter=blob:none --no-checkout "$url" "$checkout" 2>/dev/null; then
            warn "Could not check the $name marketplace, its plugins are not updated"
            rm -rf "$checkout"
            continue
        fi
        plugins=()
        all_cooled_down=1
        # Claude Code reads a plugin's marketplace entry, which can define LSP and MCP servers and
        # hooks, from the refreshed checkout on every start, also without `claude plugin update`.
        # The refresh therefore waits until the states of all declared plugins have passed the
        # cooldown. Every state is still checked, so each one's first sighting is recorded.
        for plugin in "${CLAUDE_PLUGINS[@]}"; do
            [ "${plugin#*@}" = "$name" ] || continue
            if ! state=$(plugin_state "${plugin%@*}" "$checkout" "$url"); then
                warn "Could not check $plugin in the $name marketplace, not updated"
                all_cooled_down=0
                continue
            fi
            cooled_down "$plugin" "$state" || all_cooled_down=0
            plugins+=("$plugin")
        done
        rm -rf "$checkout"
        [ "$all_cooled_down" -eq 1 ] && [ "${#plugins[@]}" -gt 0 ] || continue
        if ! claude plugin marketplace update "$name"; then
            warn "Could not refresh the $name marketplace, its plugins are not updated"
            continue
        fi
        for plugin in "${plugins[@]}"; do
            claude plugin update "$plugin" || warn "Could not update $plugin"
        done
    done 3<<< "$marketplaces"
}

# Prints the tree the skills CLI recorded for an installed skill, resolved in <checkout>. The lock
# file holds a tree hash for a skill in a subdirectory and a commit hash for one at the repository
# root; ^{tree} turns both into the tree that upstream is compared against.
installed_skill_tree() {
    local name="$1" checkout="$2" hash
    hash=$(jq -r --arg name "$name" '.skills[$name].skillFolderHash // empty' "$SKILL_LOCK_FILE" 2>/dev/null) || return 1
    [ -n "$hash" ] || return 1
    git -C "$checkout" rev-parse --verify --quiet "$hash^{tree}"
}

# Updates every skill in the skills CLI's lock file whose upstream folder differs from the
# installed one and has passed the cooldown.
update_skills_after_cooldown() {
    local entries
    if ! entries=$(jq -r '.skills // {} | to_entries[]
            | [.key, .value.sourceUrl, (.value.skillPath | sub("/?SKILL\\.md$"; ""))] | @tsv' \
            "$SKILL_LOCK_FILE" 2>/dev/null); then
        warn "Could not read $SKILL_LOCK_FILE, skills not updated"
        return 0
    fi

    local name url skill_dir checkout upstream
    # The list arrives on fd 3, so the skills CLI in the loop cannot consume it from stdin.
    while IFS=$'\t' read -r -u 3 name url skill_dir; do
        [ -n "$name" ] || continue
        # shortcut: one clone per skill, even for skills from the same repository. Each takes about
        # a second; share them per repository if the list grows.
        checkout=$(mktemp -d)
        if ! git clone --quiet --filter=blob:none --no-checkout "$url" "$checkout" 2>/dev/null \
            || ! upstream=$(git -C "$checkout" rev-parse --verify --quiet "HEAD:$skill_dir"); then
            warn "Could not check $name, not updated"
        elif [ "$upstream" != "$(installed_skill_tree "$name" "$checkout")" ] && cooled_down "$name" "$upstream"; then
            skills_cli update "$name" -g || warn "Could not update $name"
        fi
        rm -rf "$checkout"
    done 3<<< "$entries"
}
