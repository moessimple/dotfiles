history_script() {
    printf '%s\n' "$dotfiles_dir/home/.claude/skills/explain-changes/scripts/history.sh"
}

given_repository_with_file() {
    local path="$1" content="$2"
    repository="$fixture/repository"
    mkdir -p "$repository"
    git init -q -b main "$repository"
    configure_test_repository "$repository"
    commit_file "$path" "$content" "initial"
}

commit_file() {
    local path="$1" content="$2" message="$3"
    printf '%b' "$content" > "$repository/$path"
    git -C "$repository" add "$path"
    git -C "$repository" commit -qm "$message"
}

commit_file_with_reason() {
    local path="$1" content="$2" message="$3" reason="$4"
    printf '%b' "$content" > "$repository/$path"
    git -C "$repository" add "$path"
    git -C "$repository" commit -qm "$message" -m "$reason"
}

change_file_without_committing() {
    printf '%b' "$2" > "$repository/$1"
}

switch_to_branch() {
    git -C "$repository" switch -q "$1" 2>/dev/null || git -C "$repository" switch -qc "$1"
}

commit_sha() {
    git -C "$repository" log -1 --format=%H --grep="^$1\$"
}

given_github_origin() {
    git -C "$repository" remote add origin git@github.com:acme/app.git
}

given_github_returns_pull_request() {
    local number="$1" title="$2" body="$3"
    write_fake_binary gh "printf '%s\n' '[{\"number\": $number, \"title\": \"$title\", \"html_url\": \"https://github.com/acme/app/pull/$number\", \"body\": \"$body\"}]'"
}

given_github_returns_no_pull_request() {
    write_fake_binary gh "printf '[]\n'"
}

given_github_is_unreachable() {
    write_fake_binary gh "exit 1"
}

run_history_for_branch() {
    run bash -c 'cd "$1" && "$2" main "$3"' _ "$repository" "$(history_script)" "$1"
}

run_history_for_working_tree() {
    run bash -c 'cd "$1" && "$2" main' _ "$repository" "$(history_script)"
}
