call_cchangelog() {
    env PATH="$fake_bin:$PATH" CCHANGELOG_EMPTY="${CCHANGELOG_EMPTY:-}" \
        zsh -c 'source "$1"; shift; cchangelog "$@"' zsh "$functions_file" "$@"
}

given_direct_and_transitive_dependency_changes() {
    create_fake_cchangelog_tools
}

given_only_direct_dependency_changes() {
    create_fake_cchangelog_tools
    export CCHANGELOG_EMPTY=1
}

create_fake_cchangelog_tools() {
    fake_bin="$fixture/bin"
    mkdir -p "$fake_bin"

    cat > "$fake_bin/git" <<'GIT'
#!/usr/bin/env bash
[[ "$1" == "rev-parse" && "$2" == "--verify" ]]
GIT

    cat > "$fake_bin/composer" <<'COMPOSER'
#!/usr/bin/env bash
if [[ " $* " == *" --format=json "* ]]; then
    if [[ -n "${CCHANGELOG_EMPTY:-}" || " $* " == *" --direct "* ]]; then
        printf '%s\n' '{"packages":{"vendor/direct":{}},"packages-dev":{}}'
    else
        printf '%s\n' '{"packages":{"vendor/direct":{},"vendor/package.name":{}},"packages-dev":{"vendor/removed-package":{}}}'
    fi
elif [[ " $* " == *" --direct "* ]]; then
    printf '%s\n' 'vendor/direct'
else
    filtered=0
    while (( $# > 0 )); do
        if [[ "$1" == "--filter" ]]; then
            shift
            printf '%s\n' "$1"
            filtered=1
        fi
        shift
    done
    if (( filtered == 0 )); then
        printf '%s\n' 'vendor/direct' 'vendor/transitive'
    fi
fi
COMPOSER

    chmod +x "$fake_bin/git" "$fake_bin/composer"
}
