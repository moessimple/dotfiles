call_update() {
    HOME="$test_home" bash "$dotfiles_dir/bin/update.sh"
}

write_update_side_effects_that_must_not_run() {
    cat > "$bin_dir/git" <<'EOF'
#!/bin/sh
for argument in "$@"; do
    if [ "$argument" = "pull" ]; then
        touch "$UPDATE_SIDE_EFFECT_REACHED"
    fi
done
exec "$REAL_GIT" "$@"
EOF

    cat > "$bin_dir/brew" <<'EOF'
#!/bin/sh
touch "$UPDATE_SIDE_EFFECT_REACHED"
exit 1
EOF

    chmod +x "$bin_dir/git" "$bin_dir/brew"
}

assert_update_side_effect_was_not_reached() {
    [ ! -e "$UPDATE_SIDE_EFFECT_REACHED" ]
}

# Commits the real support/setup/ tree into the fixture repository, so update.sh's `source
# ~/.dotfiles/support/setup/...` calls resolve against the actual production files instead of
# a synthetic stand-in, proving the real wiring rather than a copy of it.
given_repository_with_real_setup_scripts() {
    cp -R "$dotfiles_dir/support" "$repository/support"
    find "$repository/support" -name ".DS_Store" -delete
    git -C "$repository" add support
    git -C "$repository" commit -qm "add support"
}

# Stands in for every external tool a full update.sh run drives (Homebrew, Composer, npm,
# agent-browser, the `skills` CLI via npx, and Claude Code), each reporting an empty installed
# set so every *_cleanup function reports a clean state instead of touching real package managers.
given_every_external_tool_update_touches_is_faked() {
    write_fake_binary brew
    write_fake_binary npx
    write_fake_binary agent-browser
    given_fake_composer_reporting_installed '{"installed":[]}'
    given_fake_npm_reporting_installed '{"dependencies":{}}'
    given_fake_claude '[]' ""
    given_skill_lock_file '{"skills":{}}'
}
