# Sources one support/setup/**/*.sh file with step/warn/success stubbed (the real
# definitions live in bin/install.sh and bin/update.sh, the files' actual callers), then
# invokes the named cleanup function it declares. PATH and HOME are inherited from the
# calling test so given_fake_bin_on_path fakes and a fixture HOME take effect.
call_cleanup_function() {
    local file="$1" function_name="$2"
    HOME="${test_home:-$HOME}" bash -c '
        step() { :; }
        warn() { echo "WARN: $*"; }
        success() { echo "SUCCESS: $*"; }
        source "$1"
        "$2"
    ' bash "$file" "$function_name"
}

given_fake_composer_reporting_installed() {
    local json="$1"
    cat > "$fake_bin/composer" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$fake_bin/composer.calls"
if [ "\$*" = "global show -D --format=json" ]; then
    printf '%s\n' '$json'
fi
EOF
    chmod +x "$fake_bin/composer"
}

given_fake_composer_failing_to_report_installed() {
    cat > "$fake_bin/composer" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$fake_bin/composer.calls"
[ "\$*" = "global show -D --format=json" ] && exit 1
exit 0
EOF
    chmod +x "$fake_bin/composer"
}

given_fake_npm_reporting_installed() {
    local json="$1"
    cat > "$fake_bin/npm" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$fake_bin/npm.calls"
if [ "\$*" = "ls -g --depth=0 --json" ]; then
    printf '%s\n' '$json'
fi
EOF
    chmod +x "$fake_bin/npm"
}

given_fake_npm_failing_to_report_installed() {
    cat > "$fake_bin/npm" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$fake_bin/npm.calls"
[ "\$*" = "ls -g --depth=0 --json" ] && exit 1
exit 0
EOF
    chmod +x "$fake_bin/npm"
}

given_skill_lock_file() {
    mkdir -p "$test_home/.agents"
    printf '%s' "$1" > "$test_home/.agents/.skill-lock.json"
}

given_unreadable_skill_lock_file() {
    mkdir -p "$test_home/.agents"
    printf 'not valid json' > "$test_home/.agents/.skill-lock.json"
}

# $1: JSON array for `claude plugin list --json`
# $2: newline-separated `name: ...` lines for `claude mcp list`
# Remaining args: pairs of "<name> <scope-line>" for what `claude mcp get <name>` reports,
# e.g. "chrome-devtools Scope: User config" or "project-server Scope: Project config (.mcp.json)"
given_fake_claude() {
    local plugin_list_json="$1" mcp_list_output="$2"
    shift 2

    cat > "$fake_bin/claude" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$fake_bin/claude.calls"
case "\$*" in
    "plugin list --json")
        printf '%s\n' '$plugin_list_json'
        ;;
    "mcp list")
        printf '%s\n' '$mcp_list_output'
        ;;
EOF

    while (( $# > 0 )); do
        local name="$1" scope_line="$2"
        shift 2
        cat >> "$fake_bin/claude" <<EOF
    "mcp get $name")
        printf '%s\n' '$scope_line'
        ;;
EOF
    done

    cat >> "$fake_bin/claude" <<'EOF'
esac
EOF
    chmod +x "$fake_bin/claude"
}

given_fake_claude_failing_to_report_plugins_and_mcp_servers() {
    cat > "$fake_bin/claude" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$fake_bin/claude.calls"
case "\$*" in
    "plugin list --json")
        exit 1
        ;;
    "mcp list")
        exit 1
        ;;
esac
EOF
    chmod +x "$fake_bin/claude"
}
