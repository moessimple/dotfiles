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

list_mas_apps() {
    brew bundle list --mas --file="$dotfiles_dir/support/config/Brewfile"
}

@test "without a profile the Brewfile still includes private apps" {
    # Act
    run list_casks

    # Assert
    assert_success
    [[ $'\n'"$output"$'\n' == *$'\ndiscord\n'* ]] || false
    [[ $'\n'"$output"$'\n' == *$'\nwhatsapp\n'* ]] || false
}

@test "explicit private profile preserves the default cask list" {
    # Arrange
    list_casks >"$fixture/default"
    echo private >"$HOME/.config/dotfiles/profile"

    # Act
    list_casks >"$fixture/private"

    # Assert
    cmp "$fixture/default" "$fixture/private"
}

@test "work profile excludes only Discord, OneCast and WhatsApp" {
    # Arrange
    list_casks | LC_ALL=C sort >"$fixture/private"
    echo work >"$HOME/.config/dotfiles/profile"

    # Act
    list_casks | LC_ALL=C sort >"$fixture/work"

    # Assert: these three casks are missing, and no cask is added.
    run comm -23 "$fixture/private" "$fixture/work"
    assert_success
    [ "$output" = $'discord\nonecast\nwhatsapp' ]
    run comm -13 "$fixture/private" "$fixture/work"
    assert_success
    [ -z "$output" ]
}

@test "work profile excludes only AusweisApp from the Mac App Store apps" {
    # Arrange
    list_mas_apps | LC_ALL=C sort >"$fixture/private"
    echo work >"$HOME/.config/dotfiles/profile"

    # Act
    list_mas_apps | LC_ALL=C sort >"$fixture/work"

    # Assert: AusweisApp is missing, and no app is added.
    run comm -23 "$fixture/private" "$fixture/work"
    assert_success
    [ "$output" = "AusweisApp" ]
    run comm -13 "$fixture/private" "$fixture/work"
    assert_success
    [ -z "$output" ]
}
