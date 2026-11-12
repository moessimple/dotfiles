# Sources support/setup/claude/update-cooldown.sh with the output helpers stubbed, under the set -e
# of bin/update.sh, and updates the declared <plugins> (default: laravel@laravel) from the fixture
# marketplace.
call_update_plugins_after_cooldown() {
    local plugins=("$@")
    [ "$#" -gt 0 ] || plugins=("laravel@laravel")
    HOME="$test_home" XDG_CONFIG_HOME="$test_home/.config" bash -c '
        set -e
        warn() { echo "WARN: $*"; }
        source "$1"
        shift
        CLAUDE_PLUGINS=("$@")
        update_plugins_after_cooldown
    ' bash "$dotfiles_dir/support/setup/claude/update-cooldown.sh" "${plugins[@]}"
}

# Sources claude-skills.sh, for the real skills_cli, and update-cooldown.sh with the output helpers
# stubbed, under the set -e of bin/update.sh, then updates the skills in the lock file.
call_update_skills_after_cooldown() {
    HOME="$test_home" XDG_CONFIG_HOME="$test_home/.config" HOMEBREW_PREFIX="$fixture" bash -c '
        set -e
        step() { :; }
        warn() { echo "WARN: $*"; }
        success() { :; }
        source "$1" > /dev/null
        source "$2"
        update_skills_after_cooldown
    ' bash "$dotfiles_dir/support/setup/claude/claude-skills.sh" \
        "$dotfiles_dir/support/setup/claude/update-cooldown.sh"
}

# A marketplace repository named laravel holding the laravel plugin in ./laravel and another
# plugin in ./other-plugin. <laravel entry> replaces the plugin's marketplace entry.
given_marketplace() {
    local laravel_entry='{"name":"laravel","source":"./laravel"}'
    [ -z "${1:-}" ] || laravel_entry="$1"
    marketplace_repository="$fixture/marketplace"
    git init -q -b main "$marketplace_repository"
    configure_test_repository "$marketplace_repository"
    mkdir -p "$marketplace_repository/.claude-plugin" "$marketplace_repository/laravel/skills" \
        "$marketplace_repository/other-plugin"
    jq -n --argjson laravel "$laravel_entry" '{plugins: [$laravel, {name: "other-plugin", source: "./other-plugin"}]}' \
        > "$marketplace_repository/.claude-plugin/marketplace.json"
    echo "first" > "$marketplace_repository/laravel/skills/SKILL.md"
    echo "first" > "$marketplace_repository/other-plugin/README.md"
    git -C "$marketplace_repository" add .
    git -C "$marketplace_repository" commit -qm first
    write_fake_claude_listing_marketplace
}

# A marketplace repository without any commit.
given_empty_marketplace() {
    marketplace_repository="$fixture/marketplace"
    git init -q -b main "$marketplace_repository"
    write_fake_claude_listing_marketplace
}

# Fake claude: `plugin marketplace list --json` lists the fixture marketplace; every call is recorded.
write_fake_claude_listing_marketplace() {
    write_fake_binary claude "case \"\$*\" in
    'plugin marketplace list --json') printf '%s\n' '[{\"name\":\"laravel\",\"source\":\"git\",\"url\":\"$marketplace_repository\"}]' ;;
esac"
}

# Commits a change of <path> in the marketplace repository upstream.
given_upstream_change_to() {
    local path="$1"
    mkdir -p "$(dirname "$marketplace_repository/$path")"
    echo "changed $RANDOM" >> "$marketplace_repository/$path"
    git -C "$marketplace_repository" add .
    git -C "$marketplace_repository" commit -qm "change $path"
}

# Replaces the laravel plugin's marketplace entry upstream with <entry> and commits it.
given_upstream_marketplace_entry() {
    local entry="$1" marketplace_json="$marketplace_repository/.claude-plugin/marketplace.json"
    jq --argjson entry "$entry" '.plugins |= map(if .name == "laravel" then $entry else . end)' "$marketplace_json" \
        > "$marketplace_json.tmp"
    mv "$marketplace_json.tmp" "$marketplace_json"
    git -C "$marketplace_repository" commit -qam "change the laravel entry"
}

# A skill repository with the skill in skills/<name> and an unrelated directory next to it. The
# skill is recorded in the lock file as installed from the first commit, under <source url>, which
# the test HOME's git config redirects to the fixture, so no network clone happens.
given_skill_repository() {
    local name="$1" source_url="${2:-}"
    skill_repository="$fixture/skill-repository"
    git init -q -b main "$skill_repository"
    configure_test_repository "$skill_repository"
    mkdir -p "$skill_repository/skills/$name" "$skill_repository/docs"
    echo "first" > "$skill_repository/skills/$name/SKILL.md"
    echo "first" > "$skill_repository/docs/index.md"
    git -C "$skill_repository" add .
    git -C "$skill_repository" commit -qm first
    if [ -n "$source_url" ]; then
        git config --file "$test_home/.gitconfig" url."$skill_repository".insteadOf "$source_url"
    fi
    mkdir -p "$test_home/.agents"
    jq -n --arg name "$name" --arg url "${source_url:-$skill_repository}" --arg path "skills/$name/SKILL.md" \
        --arg hash "$(git -C "$skill_repository" rev-parse "HEAD:skills/$name")" \
        '{version: 3, skills: {($name): {sourceUrl: $url, skillPath: $path, skillFolderHash: $hash}}}' \
        > "$test_home/.agents/.skill-lock.json"
    write_fake_binary npx
}

# Commits a change of <path> in the skill repository upstream.
given_skill_upstream_change_to() {
    local path="$1"
    echo "changed $RANDOM" >> "$skill_repository/$path"
    git -C "$skill_repository" add .
    git -C "$skill_repository" commit -qm "change $path"
}

# Moves every recorded first sighting <days> days into the past, as if that much time had passed.
given_first_sightings_aged_by_days() {
    local days="$1" state="$test_home/.config/claude-update-cooldown/first-seen"
    [ -f "$state" ] || return 0
    awk -F '\t' -v OFS='\t' -v seconds="$(( days * 86400 ))" '{ $3 -= seconds; print }' "$state" > "$state.tmp"
    mv "$state.tmp" "$state"
}

# Replaces the recorded first-seen time of every sighting with <value>, valid or not.
given_first_sighting_time_replaced_with() {
    local value="$1" state="$test_home/.config/claude-update-cooldown/first-seen"
    awk -F '\t' -v OFS='\t' -v value="$value" '{ $3 = value; print }' "$state" > "$state.tmp"
    mv "$state.tmp" "$state"
}

# Lets the plugin update see the current upstream state once, then ages that sighting by <days>.
given_plugin_state_seen_days_ago() {
    call_update_plugins_after_cooldown > /dev/null
    given_first_sightings_aged_by_days "$1"
    rm -f "$fake_bin/claude.calls"
}

# Lets the update of the declared <plugins> see their current upstream states once, then ages
# those sightings by <days>.
given_plugin_states_seen_days_ago() {
    local days="$1"
    shift
    call_update_plugins_after_cooldown "$@" > /dev/null
    given_first_sightings_aged_by_days "$days"
    rm -f "$fake_bin/claude.calls"
}

# Lets the skill update see the current upstream state once, then ages that sighting by <days>.
given_skill_state_seen_days_ago() {
    call_update_skills_after_cooldown > /dev/null
    given_first_sightings_aged_by_days "$1"
    rm -f "$fake_bin/npx.calls"
}
