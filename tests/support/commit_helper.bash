create_commit_repository() {
    git init -q -b main "$repository"
    configure_test_repository "$repository"
    printf 'original\n' > "$repository/tracked.txt"
    git -C "$repository" add tracked.txt
    git -C "$repository" commit -qm initial
    printf 'changed\n' > "$repository/tracked.txt"
}

call_commit() {
    zsh -c 'source "$1"; cd "$2"; commit "${@:3}"' \
        zsh "$functions_file" "$working_directory" "$@"
}

call_commit_with_input() {
    call_commit <<< "$1"
}

write_successful_claude() {
    local message="$1"

    cat > "$bin_dir/claude" <<EOF
#!/bin/sh
cat > "\$PROVIDER_INPUT"
printf '%s\n' '{"type":"result","is_error":false,"result":"$message"}'
EOF
    chmod +x "$bin_dir/claude"
}

write_successful_codex() {
    local message="$1"

    cat > "$bin_dir/codex" <<EOF
#!/bin/sh
cat > "\$PROVIDER_INPUT"
printf '%s\n' '{"type":"item.completed","item":{"type":"agent_message","text":"$message"}}'
printf '%s\n' '{"type":"turn.completed"}'
EOF
    chmod +x "$bin_dir/codex"
}

write_failing_provider() {
    local provider="$1"

    printf '#!/bin/sh\nexit 1\n' > "$bin_dir/$provider"
    chmod +x "$bin_dir/$provider"
}

write_provider_that_must_not_run() {
    local provider="$1"

    cat > "$bin_dir/$provider" <<'EOF'
#!/bin/sh
touch "$PROVIDER_CALLED"
exit 1
EOF
    chmod +x "$bin_dir/$provider"
}

write_providers_that_must_not_run() {
    write_provider_that_must_not_run claude
    write_provider_that_must_not_run codex
}

create_large_change() {
    local path="$1"
    local beginning="$2"
    local end="$3"

    printf '%s\n' "$beginning" > "$path"
    head -c 60000 /dev/zero | tr '\0' x >> "$path"
    printf '\n%s\n' "$end" >> "$path"
}

make_git_commit_fail() {
    cat > "$repository/.git/hooks/pre-commit" <<'EOF'
#!/bin/sh
exit 1
EOF
    chmod +x "$repository/.git/hooks/pre-commit"
}

assert_success() {
    [ "$status" -eq 0 ]
}

assert_failure() {
    [ "$status" -ne 0 ]
}

assert_commit_message() {
    [ "$(git -C "$repository" log -1 --format=%s)" = "$1" ]
}

assert_commit_count() {
    [ "$(git -C "$repository" rev-list --count HEAD)" -eq "$1" ]
}

assert_repository_is_clean() {
    [ -z "$(git -C "$repository" status --porcelain)" ]
}

assert_commit_contains_change() {
    local change="$1"
    local path="$2"
    local expected="${change}"$'\t'"${path}"

    git -C "$repository" show --format= --name-status HEAD | grep -qF "$expected"
}

assert_changes_are_staged() {
    ! git -C "$repository" diff --cached --quiet || false
}

assert_no_changes_are_staged() {
    git -C "$repository" diff --cached --quiet
}

assert_output_contains() {
    [[ "$output" == *"$1"* ]] || false
}

assert_provider_received() {
    grep -qF "$1" "$fixture/provider-input"
}

assert_provider_did_not_receive() {
    ! grep -qF "$1" "$fixture/provider-input" || false
}

assert_provider_was_not_called() {
    [ ! -e "$fixture/provider-called" ]
}
