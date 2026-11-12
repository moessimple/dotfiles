#!/usr/bin/env bats

load ../support/test_helper

setup() {
    new_dotfiles_fixture
    export HOME="$fixture/home"
    export GIT_CONFIG_NOSYSTEM=1
    unset GIT_CONFIG_GLOBAL
    mkdir -p "$HOME"
    cp "$dotfiles_dir/home/.gitconfig" "$HOME/.gitconfig"
    profile_file="$HOME/.config/dotfiles/profile"
}

teardown() {
    teardown_dotfiles_fixture
}

configure_profile() (
    # Stop the real installer after profile setup, before any machine changes.
    sudo() { exit 73; }
    export -f sudo
    if { printf 'y\n'; cat; } | /bin/bash "$dotfiles_dir/bin/install.sh"; then
        return 0
    else
        result=$?
    fi
    if [ "$result" -eq 73 ]; then
        return 0
    fi
    return "$result"
)

@test "private selection stores its email locally" {
    run configure_profile <<< $'1\nprivate@example.invalid'
    assert_success
    [ "$(cat "$profile_file")" = private ]
    [ "$(git config --global --includes user.email)" = private@example.invalid ]
}

@test "private setup offers the existing global email as a default" {
    git config --global user.email existing@example.invalid
    run configure_profile <<< $'1\n'
    assert_success
    [ "$(git config --file "$HOME/.gitconfig-local" user.email)" = existing@example.invalid ]
}

@test "private setup allows replacing the suggested email" {
    git config --global user.email existing@example.invalid
    run configure_profile <<< $'1\nother@example.invalid'
    assert_success
    [ "$(git config --file "$HOME/.gitconfig-local" user.email)" = other@example.invalid ]
}

@test "a missing local email prevents commits instead of using a private default" {
    git init -q "$fixture/repository"
    run git -C "$fixture/repository" -c commit.gpgsign=false commit --allow-empty -m test
    assert_failure
    git config --file "$HOME/.gitconfig-local" user.email developer@example.invalid
    run git -C "$fixture/repository" -c commit.gpgsign=false commit --allow-empty -m test
    assert_success
    rm "$HOME/.gitconfig-local"
    run git -C "$fixture/repository" -c commit.gpgsign=false commit --allow-empty -m test
    assert_failure
}

@test "an explicit repository email can override the machine identity" {
    git init -q "$fixture/repository"
    git -C "$fixture/repository" config user.email project@example.invalid
    run git -C "$fixture/repository" -c commit.gpgsign=false commit --allow-empty -m test
    assert_success
    [ "$(git -C "$fixture/repository" log -1 --format=%ae)" = project@example.invalid ]
}

@test "work selection stores only the email locally and inherits the name" {
    name=$(git config --global user.name)
    run configure_profile <<< $'2\ndeveloper@example.invalid'
    assert_success
    [ "$(cat "$profile_file")" = work ]
    [ "$(git config --global --includes user.email)" = developer@example.invalid ]
    [ "$(git config --global --includes user.name)" = "$name" ]
    [ "$(git config --file "$HOME/.gitconfig-local" --list)" = user.email=developer@example.invalid ]
}

@test "existing local settings survive work email setup" {
    git config --file "$HOME/.gitconfig-local" user.signingkey test-key
    run configure_profile <<< $'2\ndeveloper@example.invalid'
    assert_success
    [ "$(git config --file "$HOME/.gitconfig-local" user.signingkey)" = test-key ]
}

@test "a saved profile skips all questions and preserves its email" {
    configure_profile <<< $'2\ndeveloper@example.invalid'
    run configure_profile </dev/null
    assert_success
    [[ "$output" != *'What kind of machine'* ]]
    [ "$(git config --global --includes user.email)" = developer@example.invalid ]
}

@test "install setup asks only for the missing email when a profile already exists" {
    mkdir -p "$(dirname "$profile_file")"
    echo work > "$profile_file"
    run configure_profile <<< 'developer@example.invalid'
    assert_success
    [[ "$output" != *'What kind of machine'* ]]
    [ "$(cat "$profile_file")" = work ]
    [ "$(git config --file "$HOME/.gitconfig-local" user.email)" = developer@example.invalid ]
}

@test "a saved profile with a blank local email still needs email setup" {
    mkdir -p "$(dirname "$profile_file")"
    echo private > "$profile_file"
    git config --file "$HOME/.gitconfig-local" user.email '   '
    run configure_profile <<< 'private@example.invalid'
    assert_success
    [ "$(git config --file "$HOME/.gitconfig-local" user.email)" = private@example.invalid ]
}

@test "invalid selection and blank email are asked again" {
    run configure_profile <<< $'wrong\n2\n   \ndeveloper@example.invalid'
    assert_success
    [ "$(cat "$profile_file")" = work ]
    [ "$(git config --global --includes user.email)" = developer@example.invalid ]
}

@test "aborted input does not save a profile" {
    run configure_profile </dev/null
    assert_failure
    [ ! -e "$profile_file" ]
    run configure_profile <<< '2'
    assert_failure
    [ ! -e "$profile_file" ]
    [ ! -e "$HOME/.gitconfig-local" ]
}

@test "no saved profile reads as private without questions or writes" {
    run /bin/bash -ec 'source "$1/support/setup/output.sh"; source "$1/support/setup/machine-profile.sh"; printf "%s" "$DOTFILES_PROFILE"' bash "$dotfiles_dir"
    assert_success
    [ "$output" = private ]
    [ ! -e "$profile_file" ]
}

@test "an invalid saved profile is reported instead of silently choosing private" {
    mkdir -p "$(dirname "$profile_file")"
    echo invalid > "$profile_file"
    run configure_profile </dev/null
    assert_failure
    assert_output_contains 'Invalid machine profile'
}

@test "install configures the profile before sudo and skips questions on a second run" {
    sudo() { exit 73; }
    export -f sudo
    run /bin/bash "$dotfiles_dir/bin/install.sh" <<< $'y\n2\ndeveloper@example.invalid'
    [ "$status" -eq 73 ]
    [ "$(cat "$profile_file")" = work ]
    run /bin/bash "$dotfiles_dir/bin/install.sh" <<< 'y'
    [ "$status" -eq 73 ]
    [[ "$output" != *'1) Private'* ]]
}

@test "declining installation does not configure a profile" {
    run /bin/bash "$dotfiles_dir/bin/install.sh" <<< 'n'
    assert_success
    [ ! -e "$profile_file" ]
}

@test "a failed Git config write does not save the selected work profile" {
    printf '[broken\n' > "$HOME/.gitconfig-local"
    run configure_profile <<< $'2\ndeveloper@example.invalid'
    assert_failure
    assert_output_contains 'Could not save the Git email'
    [ ! -e "$profile_file" ]
}

@test "reconfigure and update accept a saved work profile without identity checks or prompts" {
    mkdir -p "$(dirname "$profile_file")"
    echo work > "$profile_file"
    sudo() { exit 73; }
    export -f sudo
    run /bin/bash "$dotfiles_dir/bin/reconfigure.sh" </dev/null
    [ "$status" -eq 73 ]
    run /bin/bash "$dotfiles_dir/bin/update.sh" </dev/null
    assert_failure
    assert_output_contains '~/.dotfiles is not a Git repository.'
    [ ! -e "$HOME/.gitconfig-local" ]
}

@test "update rejects an invalid profile before repository or package operations" {
    mkdir -p "$(dirname "$profile_file")"
    echo invalid > "$profile_file"
    run /bin/bash "$dotfiles_dir/bin/update.sh" </dev/null
    assert_failure
    assert_output_contains 'Invalid machine profile'
    [[ "$output" != *'Pulling latest changes'* ]]
}

@test "reconfigure rejects an invalid profile before sudo or machine changes" {
    mkdir -p "$(dirname "$profile_file")"
    echo invalid > "$profile_file"
    sudo() { exit 73; }
    export -f sudo
    run /bin/bash "$dotfiles_dir/bin/reconfigure.sh" </dev/null
    [ "$status" -eq 1 ]
    assert_output_contains 'Invalid machine profile'
}
