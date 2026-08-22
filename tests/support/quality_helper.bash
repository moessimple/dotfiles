call_quality() {
    call_dotfiles_function quality "$@"
}

call_quality_in() {
    local directory="$1"
    shift
    call_dotfiles_function_in "$directory" quality "$@"
}

# Points $HOME at a fixture directory that carries a fake quality-gate.sh
# (recording its invocations) alongside the project's real project-root.sh,
# since `quality status` reads the project root through that real helper.
given_fake_home_with_quality_gate() {
    fake_home="$fixture/home"
    mkdir -p "$fake_home/.claude/hooks/support"
    cp "$dotfiles_dir/home/.claude/hooks/support/project-root.sh" \
        "$fake_home/.claude/hooks/support/project-root.sh"
    cat > "$fake_home/.claude/hooks/quality-gate.sh" <<'SCRIPT'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$(dirname "$0")/quality-gate.calls"
SCRIPT
    chmod +x "$fake_home/.claude/hooks/quality-gate.sh"
    export HOME="$fake_home"
}

given_composer_project_repository() {
    given_clean_repository_on_main
    printf '{}\n' > "$repository/composer.json"
    git -C "$repository" add composer.json
    git -C "$repository" commit -qm "add composer.json"
}

assert_quality_gate_called_with() {
    grep -qxF -- "$1" "$fake_home/.claude/hooks/quality-gate.calls"
}

assert_quality_gate_not_called() {
    [ ! -f "$fake_home/.claude/hooks/quality-gate.calls" ]
}
