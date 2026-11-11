# Sources support/setup/claude/update-review.sh with the output helpers stubbed and reviews the
# laravel@laravel update from $installed_commit to $upstream_commit. The answer to the
# [y/N] question comes from the caller's stdin.
call_review_plugin_update() {
    HOME="$test_home" bash -c '
        warn() { echo "WARN: $*"; }
        success() { echo "SUCCESS: $*"; }
        source "$1"
        review_plugin_update laravel@laravel laravel "$2" "$3" "$4"
    ' bash "$dotfiles_dir/support/setup/claude/update-review.sh" \
        "$marketplace_repository" "$installed_commit" "$upstream_commit"
}

# A marketplace repository holding the laravel plugin in ./laravel and another plugin in
# ./other-plugin, with laravel@laravel recorded as installed from the first commit.
given_marketplace_at_first_commit() {
    marketplace_repository="$fixture/marketplace"
    git init -q -b main "$marketplace_repository"
    configure_test_repository "$marketplace_repository"
    mkdir -p "$marketplace_repository/.claude-plugin" "$marketplace_repository/laravel/skills" \
        "$marketplace_repository/other-plugin"
    printf '%s\n' '{"plugins":[{"name":"laravel","source":"./laravel"},{"name":"other-plugin","source":"./other-plugin"}]}' \
        > "$marketplace_repository/.claude-plugin/marketplace.json"
    echo "first" > "$marketplace_repository/laravel/skills/SKILL.md"
    echo "first" > "$marketplace_repository/other-plugin/README.md"
    git -C "$marketplace_repository" add .
    git -C "$marketplace_repository" commit -qm first
    installed_commit=$(git -C "$marketplace_repository" rev-parse HEAD)
    printf '%s\n' "{\"plugins\":{\"laravel@laravel\":[{\"gitCommitSha\":\"$installed_commit\"}]}}" \
        > "$test_home/.claude/plugins/installed_plugins.json"
}

given_marketplace_with_plugin_change() {
    given_marketplace_at_first_commit
    echo "second" > "$marketplace_repository/laravel/skills/SKILL.md"
    echo "second" > "$marketplace_repository/other-plugin/README.md"
    git -C "$marketplace_repository" commit -qam second
    upstream_commit=$(git -C "$marketplace_repository" rev-parse HEAD)
    plugin_update_installs_commit="$upstream_commit"
}

given_marketplace_with_change_outside_plugin() {
    given_marketplace_at_first_commit
    echo "second" > "$marketplace_repository/other-plugin/README.md"
    git -C "$marketplace_repository" commit -qam second
    upstream_commit=$(git -C "$marketplace_repository" rev-parse HEAD)
    plugin_update_installs_commit="$upstream_commit"
}

# Must follow given_fake_claude_reviewing, which writes the fake that reads this value.
given_plugin_update_installs_commit() {
    plugin_update_installs_commit="$1"
    write_fake_claude "$fake_claude_review_body"
}

# Fake claude: `-p` saves its stdin to claude.review-input and answers with the given review;
# `plugin update laravel@laravel` records $plugin_update_installs_commit as installed.
given_fake_claude_reviewing() {
    fake_claude_review_body="cat > \"$fake_bin/claude.review-input\"; printf '%s\n' '$1'"
    write_fake_claude "$fake_claude_review_body"
}

given_fake_claude_failing_review() {
    fake_claude_review_body="cat > /dev/null; exit 1"
    write_fake_claude "$fake_claude_review_body"
}

write_fake_claude() {
    local review_body="$1"
    write_fake_binary claude "case \"\$1 \$2\" in
    '-p '*) $review_body ;;
    'plugin update') printf '%s\n' '{\"plugins\":{\"laravel@laravel\":[{\"gitCommitSha\":\"$plugin_update_installs_commit\"}]}}' > \"\$HOME/.claude/plugins/installed_plugins.json\" ;;
esac"
}

assert_review_input_contains() {
    grep -qF -- "$1" "$fake_bin/claude.review-input"
}

assert_review_input_does_not_contain() {
    ! grep -qF -- "$1" "$fake_bin/claude.review-input" || false
}

# Sources claude-skills.sh, for the real skills_cli, and update-review.sh with the output helpers
# stubbed, then runs review_skill_updates. <interactive> is 1 or 0; answers come from stdin.
call_review_skill_updates() {
    local interactive="$1"
    HOME="$test_home" HOMEBREW_PREFIX="$fixture" bash -c '
        step() { :; }
        warn() { echo "WARN: $*"; }
        success() { echo "SUCCESS: $*"; }
        source "$1" > /dev/null
        source "$2"
        review_skill_updates "$3"
    ' bash "$dotfiles_dir/support/setup/claude/claude-skills.sh" \
        "$dotfiles_dir/support/setup/claude/update-review.sh" "$interactive"
}

# A skill repository with the skill in skills/<name> and an unrelated directory next to it. The
# skill is recorded in the lock file as installed from the first commit, under <source url>.
given_skill_repository_at_first_commit() {
    local name="$1" source_url="${2:-}"
    skill_repository="$fixture/skill-repository"
    git init -q -b main "$skill_repository"
    configure_test_repository "$skill_repository"
    mkdir -p "$skill_repository/skills/$name" "$skill_repository/docs"
    echo "first" > "$skill_repository/skills/$name/SKILL.md"
    echo "first" > "$skill_repository/docs/index.md"
    git -C "$skill_repository" add .
    git -C "$skill_repository" commit -qm first
    given_skill_lock_entry "$name" "${source_url:-$skill_repository}" "skills/$name/SKILL.md" \
        "$(git -C "$skill_repository" rev-parse "HEAD:skills/$name")"
}

# Like given_skill_repository_at_first_commit, for a skill at the repository root, which the
# skills CLI records with the commit hash instead of the folder's tree hash.
given_root_skill_repository_at_first_commit() {
    local name="$1"
    skill_repository="$fixture/skill-repository"
    git init -q -b main "$skill_repository"
    configure_test_repository "$skill_repository"
    echo "first" > "$skill_repository/SKILL.md"
    git -C "$skill_repository" add .
    git -C "$skill_repository" commit -qm first
    given_skill_lock_entry "$name" "$skill_repository" "SKILL.md" "$(git -C "$skill_repository" rev-parse HEAD)"
}

given_skill_lock_entry() {
    local name="$1" source_url="$2" skill_path="$3" folder_hash="$4"
    mkdir -p "$test_home/.agents"
    printf '%s\n' "{\"version\":3,\"skills\":{\"$name\":{\"sourceUrl\":\"$source_url\",\"skillPath\":\"$skill_path\",\"skillFolderHash\":\"$folder_hash\"}}}" \
        > "$test_home/.agents/.skill-lock.json"
}

given_skill_changed_upstream() {
    local name="$1"
    echo "second" > "$skill_repository/skills/$name/SKILL.md"
    echo "second" > "$skill_repository/docs/index.md"
    git -C "$skill_repository" commit -qam second
    upstream_skill_tree=$(git -C "$skill_repository" rev-parse "HEAD:skills/$name")
}

# Fake npx standing in for the skills CLI: `update <name> -g` records the upstream skill folder of
# the fixture repository as installed, the way the real CLI rewrites its lock file.
given_fake_skills_cli_updating() {
    local name="$1"
    write_fake_binary npx "if [[ \"\$*\" == *' update $name -g' ]]; then
    jq --arg hash \"\$(git -C '$skill_repository' rev-parse 'HEAD:skills/$name')\" \
        '.skills[\"$name\"].skillFolderHash = \$hash' \"\$HOME/.agents/.skill-lock.json\" > \"\$HOME/.agents/lock.tmp\"
    mv \"\$HOME/.agents/lock.tmp\" \"\$HOME/.agents/.skill-lock.json\"
fi"
}
