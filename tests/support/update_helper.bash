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

assert_current_branch() {
    [ "$("$REAL_GIT" -C "$repository" branch --show-current)" = "$1" ]
}

assert_head_is_detached() {
    [ -z "$("$REAL_GIT" -C "$repository" branch --show-current)" ]
}

assert_worktree_is_dirty() {
    [ -n "$("$REAL_GIT" -C "$repository" status --porcelain)" ]
}

assert_update_side_effect_was_not_reached() {
    [ ! -e "$UPDATE_SIDE_EFFECT_REACHED" ]
}
