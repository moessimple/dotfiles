#!/usr/bin/env bats

load ../support/test_helper

setup() {
    new_dotfiles_fixture
    export HOME="$fixture/home"
    export HOMEBREW_CACHE="$fixture/cache"
    export HOMEBREW_NO_AUTO_UPDATE=1
    export HOMEBREW_NO_ANALYTICS=1
    export HOMEBREW_NO_INSTALL_FROM_API=1
    mkdir -p "$HOME/.config/dotfiles"
}

teardown() {
    teardown_dotfiles_fixture
}

list_casks() {
    brew bundle list --cask --file="$dotfiles_dir/support/config/Brewfile"
}

@test "without a profile the Brewfile still includes private apps" {
    run list_casks
    assert_success
    [[ $'\n'"$output"$'\n' == *$'\ndiscord\n'* ]]
    [[ $'\n'"$output"$'\n' == *$'\nwhatsapp\n'* ]]
}

@test "explicit private profile preserves the default cask list" {
    list_casks > "$fixture/default"
    echo private > "$HOME/.config/dotfiles/profile"
    list_casks > "$fixture/private"
    cmp "$fixture/default" "$fixture/private"
}

@test "work profile excludes only Discord and WhatsApp" {
    list_casks | LC_ALL=C sort > "$fixture/private"
    echo work > "$HOME/.config/dotfiles/profile"
    list_casks | LC_ALL=C sort > "$fixture/work"
    run comm -23 "$fixture/private" "$fixture/work"
    assert_success
    [ "$output" = $'discord\nwhatsapp' ]
    run comm -13 "$fixture/private" "$fixture/work"
    assert_success
    [ -z "$output" ]
}
