#!/usr/bin/env bats

load ../support/test_helper

setup() {
    new_dotfiles_fixture
}

teardown() {
    teardown_dotfiles_fixture
}

@test "cchangelog --direct shows direct dependency changes" {
    create_fake_cchangelog_tools

    run env PATH="$fake_bin:$PATH" \
        zsh -c 'source "$1"; cchangelog --direct main' zsh "$functions_file"

    [ "$status" -eq 0 ]
    [ "$output" = "vendor/direct" ]
}

@test "cchangelog --indirect shows only transitive dependency changes" {
    create_fake_cchangelog_tools

    run env PATH="$fake_bin:$PATH" \
        zsh -c 'source "$1"; cchangelog --indirect main' zsh "$functions_file"

    [ "$status" -eq 0 ]
    [ "$output" = $'vendor/package.name\nvendor/removed-package' ]
}

@test "cchangelog --indirect explains when no transitive dependency changed" {
    create_fake_cchangelog_tools

    run env PATH="$fake_bin:$PATH" CCHANGELOG_EMPTY=1 \
        zsh -c 'source "$1"; cchangelog --indirect main' zsh "$functions_file"

    [ "$status" -eq 0 ]
    [ "$output" = "No indirect dependency changes." ]
}

@test "cchangelog --all shows direct and transitive dependency changes" {
    create_fake_cchangelog_tools

    run env PATH="$fake_bin:$PATH" \
        zsh -c 'source "$1"; cchangelog --all main' zsh "$functions_file"

    [ "$status" -eq 0 ]
    [ "$output" = $'vendor/direct\nvendor/transitive' ]
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
