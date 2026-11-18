# Sources one support/setup/**/*.sh file with step/warn/success stubbed (the real
# definitions live in support/setup/output.sh, which the entry points in bin/ source), then
# invokes the named cleanup function it declares. PATH and HOME are inherited from the
# calling test so given_fake_bin_on_path fakes and a fixture HOME take effect. HOMEBREW_PREFIX
# points at the fixture, so a call through $HOMEBREW_PREFIX/bin reaches those fakes too and
# never the real Homebrew binaries. errexit is on, as in the bin/ entry points that source it.
call_cleanup_function() {
    local file="$1" function_name="$2"
    HOME="${test_home:-$HOME}" HOMEBREW_PREFIX="$fixture" bash -ec '
        step() { :; }
        warn() { echo "WARN: $*"; }
        note() { echo "NOTE: $*"; }
        success() { echo "SUCCESS: $*"; }
        source "$1"
        "$2"
    ' bash "$file" "$function_name"
}

# Sources one support/setup/**/*.sh file with the output helpers stubbed, running only
# its top-level body (no cleanup function). For asserting on what the install step does.
# The STEP:/WARN:/SUCCESS:/ERROR: prefixes make each helper's lines assertable; error exits
# like the real one. Other environment variables pass through from the caller. errexit is on,
# as in the bin/ entry points that source it.
run_setup_script() {
    local file="$1"
    HOME="${test_home:-$HOME}" HOMEBREW_PREFIX="$fixture" bash -ec '
        step() { echo "STEP: $*"; }
        warn() { echo "WARN: $*"; }
        note() { echo "NOTE: $*"; }
        success() { echo "SUCCESS: $*"; }
        error() { echo "ERROR: $*"; exit 1; }
        source "$1"
    ' bash "$file"
}

# Like run_setup_script, then calls each <function> from that file in order, the way an entry
# point in bin/ calls them after sourcing.
call_setup_function() {
    local file="$1"
    shift
    HOME="${test_home:-$HOME}" HOMEBREW_PREFIX="$fixture" bash -ec '
        step() { echo "STEP: $*"; }
        warn() { echo "WARN: $*"; }
        note() { echo "NOTE: $*"; }
        success() { echo "SUCCESS: $*"; }
        error() { echo "ERROR: $*"; exit 1; }
        source "$1"
        shift
        for function_name in "$@"; do
            "$function_name"
        done
    ' bash "$file" "$@"
}

given_fake_composer_reporting_installed() {
    local json="$1"
    cat >"$fake_bin/composer" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$fake_bin/composer.calls"
if [ "\$*" = "global show -D --format=json" ]; then
    printf '%s\n' '$json'
fi
EOF
    chmod +x "$fake_bin/composer"
}

given_fake_composer_failing_to_report_installed() {
    cat >"$fake_bin/composer" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$fake_bin/composer.calls"
[ "\$*" = "global show -D --format=json" ] && exit 1
exit 0
EOF
    chmod +x "$fake_bin/composer"
}

given_fake_npm_reporting_installed() {
    local json="$1"
    cat >"$fake_bin/npm" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$fake_bin/npm.calls"
if [ "\$*" = "ls -g --depth=0 --json" ]; then
    printf '%s\n' '$json'
fi
EOF
    chmod +x "$fake_bin/npm"
}

given_fake_npm_failing_to_report_installed() {
    cat >"$fake_bin/npm" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$fake_bin/npm.calls"
[ "\$*" = "ls -g --depth=0 --json" ] && exit 1
exit 0
EOF
    chmod +x "$fake_bin/npm"
}

# Each recorded call is prefixed with PIP_BREAK_SYSTEM_PACKAGES=<value>, because Homebrew's
# real pip refuses to install or uninstall without it and the fake cannot refuse on its own.
given_fake_python_reporting_installed() {
    local json="$1"
    cat >"$fake_bin/python3" <<EOF
#!/usr/bin/env bash
printf '%s\n' "PIP_BREAK_SYSTEM_PACKAGES=\${PIP_BREAK_SYSTEM_PACKAGES:-} \$*" >> "$fake_bin/python3.calls"
case "\$*" in
    "-m pip list --user --not-required --format=json "*)
        printf '%s\n' '$json'
        ;;
esac
EOF
    chmod +x "$fake_bin/python3"
}

given_fake_python_failing_to_report_installed() {
    cat >"$fake_bin/python3" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$fake_bin/python3.calls"
case "\$*" in
    "-m pip list "*) exit 1 ;;
esac
EOF
    chmod +x "$fake_bin/python3"
}

given_skill_lock_file() {
    mkdir -p "$test_home/.agents"
    printf '%s' "$1" >"$test_home/.agents/.skill-lock.json"
}

given_unreadable_skill_lock_file() {
    mkdir -p "$test_home/.agents"
    printf 'not valid json' >"$test_home/.agents/.skill-lock.json"
}

# $1: JSON array for `claude plugin list --json`
# $2: newline-separated `name: ...` lines for `claude mcp list`
# Remaining args: pairs of "<name> <scope-line>" for what `claude mcp get <name>` reports,
# e.g. "chrome-devtools Scope: User config" or "project-server Scope: Project config (.mcp.json)"
given_fake_claude() {
    local plugin_list_json="$1" mcp_list_output="$2"
    shift 2

    cat >"$fake_bin/claude" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$fake_bin/claude.calls"
case "\$*" in
    "plugin list --json")
        [ ! -e "$fake_bin/plugin-list-fails" ] || exit 1
        printf '%s\n' '$plugin_list_json'
        ;;
    "plugin marketplace add "*)
        # Like the real CLI, rewrites the marketplace's settings entry without "autoUpdate",
        # writing through the symlink.
        settings="\$HOME/.claude/settings.json"
        if [ -f "\$settings" ]; then
            url="\${4%.git}"
            updated=\$(jq --arg url "\$url" '.extraKnownMarketplaces |= with_entries(
                if (.value.source.url | sub("\\\\.git\$"; "")) == \$url then .value |= del(.autoUpdate) else . end)' "\$settings")
            printf '%s\n' "\$updated" > "\$settings"
        fi
        ;;
    "plugin install "*)
        [ ! -e "$fake_bin/plugin-install-fails" ] || exit 1
        ;;
    "plugin marketplace list --json")
        [ -e "$fake_bin/marketplace-list-fails" ] && exit 1
        cat "$fake_bin/known-marketplaces.json" 2>/dev/null || printf '[]\n'
        ;;
    "mcp list")
        printf '%s\n' '$mcp_list_output'
        ;;
EOF

    while (($# > 0)); do
        local name="$1" scope_line="$2"
        shift 2
        cat >>"$fake_bin/claude" <<EOF
    "mcp get $name")
        printf '%s\n' '$scope_line'
        ;;
EOF
    done

    # Like the real CLI, `mcp get` fails for a server that is not configured.
    cat >>"$fake_bin/claude" <<'EOF'
    "mcp get "*)
        exit 1
        ;;
esac
EOF
    chmod +x "$fake_bin/claude"
}

# Makes the fake from given_fake_claude list these git URLs in `claude plugin marketplace list --json`.
given_claude_knows_marketplaces() {
    local url
    for url in "$@"; do
        jq -n --arg url "$url" '{name: "known", source: "git", url: $url}'
    done | jq -s . >"$fake_bin/known-marketplaces.json"
}

given_claude_failing_to_list_marketplaces() {
    touch "$fake_bin/marketplace-list-fails"
}

given_claude_failing_to_install_plugins() {
    touch "$fake_bin/plugin-install-fails"
}

given_skills_cli_failing_to_add_skills() {
    write_fake_binary npx 'case "$*" in *" add "*) exit 1 ;; esac'
}

# A settings.json in the test HOME that is a symlink into a repository copy, as dotfile-links.sh
# links it, declaring the marketplace at <url> with "autoUpdate": false.
given_settings_linked_from_repository_with_marketplace() {
    local url="$1"
    mkdir -p "$fixture/repository" "$test_home/.claude"
    jq -n --arg url "$url" '{extraKnownMarketplaces: {impeccable: {source: {source: "git", url: $url}, autoUpdate: false}}}' \
        >"$fixture/repository/settings.json"
    ln -sf "$fixture/repository/settings.json" "$test_home/.claude/settings.json"
}

assert_marketplace_auto_update_off() {
    jq -e --arg url "$1" '.extraKnownMarketplaces | any(.[]; .source.url == $url and .autoUpdate == false)' \
        "$fixture/repository/settings.json" >/dev/null
}

assert_settings_still_linked_into_repository() {
    [ "$(readlink "$test_home/.claude/settings.json")" = "$fixture/repository/settings.json" ]
}

given_fake_claude_failing_to_report_plugins_and_mcp_servers() {
    cat >"$fake_bin/claude" <<EOF
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

# $1: model names `ollama list` reports, one per line, printed below its header row
given_fake_ollama_listing() {
    local models="$1"
    cat >"$fake_bin/ollama" <<EOF2
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$fake_bin/ollama.calls"
if [ "\$*" = "list" ]; then
    printf '%s\n' 'NAME    ID    SIZE    MODIFIED'
    printf '%s\n' '$models' | sed '/^\$/d; s/\$/    0123456789ab    1.0 GB    2 days ago/'
fi
EOF2
    chmod +x "$fake_bin/ollama"
}

given_fake_ollama_failing_to_list() {
    cat >"$fake_bin/ollama" <<EOF2
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$fake_bin/ollama.calls"
[ "\$*" = "list" ] && exit 1
exit 0
EOF2
    chmod +x "$fake_bin/ollama"
}

# A second npm, standing in for Herd's, placed ahead of the Homebrew fakes on PATH, as Herd's
# NVM Node is in an interactive shell. It records its calls in herd_npm_calls.
given_herd_npm_first_on_path() {
    local herd_bin="$fixture/herd/bin"
    herd_npm_calls="$herd_bin/npm.calls"
    mkdir -p "$herd_bin"
    printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "%s"\n' "$herd_npm_calls" >"$herd_bin/npm"
    chmod +x "$herd_bin/npm"
    export PATH="$herd_bin:$PATH"
}

assert_herd_npm_not_called() {
    [ ! -e "$herd_npm_calls" ]
}

# Points $target at a fixture copy of the setup script with the given pin, so tests do not
# break each time bin/update.sh raises the real pin.
given_setup_script_pinned() {
    local variable="$1" version="$2" copy
    copy="$fixture/$(basename "$target")"
    sed "s/^$variable=\".*\"$/$variable=\"$version\"/" "$target" >"$copy"
    target="$copy"
}

# Sources one support/setup/**/*.sh file with the output helpers silenced, calls <function>, and
# prints every shell variable the call created. The entry points in bin/ source all setup files
# into one shell, so a variable one step leaves behind is visible to every later step.
list_variables_left_by_setup_function() {
    local file="$1" function_name="$2"
    HOME="${test_home:-$HOME}" HOMEBREW_PREFIX="$fixture" bash -c '
        step() { :; }
        warn() { :; }
        note() { :; }
        success() { :; }
        error() { exit 1; }
        source "$1"
        variables_before=$(compgen -v)
        "$2" &>/dev/null
        compgen -v | grep -vxF -e variables_before -f <(printf "%s\n" "$variables_before") || true
    ' bash "$file" "$function_name"
}
