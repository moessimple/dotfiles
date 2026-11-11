# Sources support/setup/claude/plugin-review.sh with the output helpers stubbed and reviews the
# laravel@laravel update from $installed_commit to $upstream_commit. The answer to the
# [y/N] question comes from the caller's stdin.
call_review_plugin_update() {
    HOME="$test_home" bash -c '
        warn() { echo "WARN: $*"; }
        success() { echo "SUCCESS: $*"; }
        source "$1"
        review_plugin_update laravel@laravel laravel "$2" "$3" "$4"
    ' bash "$dotfiles_dir/support/setup/claude/plugin-review.sh" \
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
