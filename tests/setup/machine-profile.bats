#!/usr/bin/env bats

load ../support/test_helper

setup() {
    new_dotfiles_fixture
    export HOME="$fixture/home"
    export GIT_CONFIG_NOSYSTEM=1
    unset GIT_CONFIG_GLOBAL
    mkdir -p "$HOME/.dotfiles"
    cp -R "$dotfiles_dir/support" "$HOME/.dotfiles/"
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
    if {
        printf 'y\n'
        cat
    } | /bin/bash "$dotfiles_dir/bin/install.sh"; then
        return 0
    else
        result="$?"
    fi
    if [ "$result" -eq 73 ]; then
        return 0
    fi
    return "$result"
)

@test "private selection stores its email locally" {
    # Act
    run configure_profile <<<$'1\nprivate@example.invalid'

    # Assert
    assert_success
    [ "$(cat "$profile_file")" = private ]
    [ "$(git config --global --includes user.email)" = private@example.invalid ]
}

@test "private setup offers the existing global email as a default" {
    # Arrange
    git config --global user.email existing@example.invalid

    # Act
    run configure_profile <<<$'1\n'

    # Assert
    assert_success
    [ "$(git config --file "$HOME/.gitconfig-local" user.email)" = existing@example.invalid ]
}

@test "private setup allows replacing the suggested email" {
    # Arrange
    git config --global user.email existing@example.invalid

    # Act
    run configure_profile <<<$'1\nother@example.invalid'

    # Assert
    assert_success
    [ "$(git config --file "$HOME/.gitconfig-local" user.email)" = other@example.invalid ]
}

@test "a missing local email prevents commits instead of using a private default" {
    # Arrange
    git init -q "$fixture/repository"

    # Act: commit without a machine-local email.
    run git -C "$fixture/repository" -c commit.gpgsign=false commit --allow-empty -m test

    # Assert: the commit is refused.
    assert_failure

    # Act: configure the machine-local email and commit again.
    git config --file "$HOME/.gitconfig-local" user.email developer@example.invalid
    run git -C "$fixture/repository" -c commit.gpgsign=false commit --allow-empty -m test

    # Assert: the commit succeeds.
    assert_success

    # Act: remove the machine-local email and commit again.
    rm "$HOME/.gitconfig-local"
    run git -C "$fixture/repository" -c commit.gpgsign=false commit --allow-empty -m test

    # Assert: the commit is refused again.
    assert_failure
}

@test "an explicit repository email can override the machine identity" {
    # Arrange
    git init -q "$fixture/repository"
    git -C "$fixture/repository" config user.email project@example.invalid

    # Act
    run git -C "$fixture/repository" -c commit.gpgsign=false commit --allow-empty -m test

    # Assert
    assert_success
    [ "$(git -C "$fixture/repository" log -1 --format=%ae)" = project@example.invalid ]
}

@test "work selection stores only the email locally and inherits the name" {
    # Arrange
    name="$(git config --global user.name)"

    # Act
    run configure_profile <<<$'2\ndeveloper@example.invalid'

    # Assert
    assert_success
    [ "$(cat "$profile_file")" = work ]
    [ "$(git config --global --includes user.email)" = developer@example.invalid ]
    [ "$(git config --global --includes user.name)" = "$name" ]
    [ "$(git config --file "$HOME/.gitconfig-local" --list)" = user.email=developer@example.invalid ]
}

@test "existing local settings survive work email setup" {
    # Arrange
    git config --file "$HOME/.gitconfig-local" user.signingkey test-key

    # Act
    run configure_profile <<<$'2\ndeveloper@example.invalid'

    # Assert
    assert_success
    [ "$(git config --file "$HOME/.gitconfig-local" user.signingkey)" = test-key ]
}

@test "a saved profile skips all questions and preserves its email" {
    # Arrange
    configure_profile <<<$'2\ndeveloper@example.invalid'

    # Act
    run configure_profile </dev/null

    # Assert
    assert_success
    [[ "$output" != *'What kind of machine'* ]] || false
    [ "$(git config --global --includes user.email)" = developer@example.invalid ]
}

@test "install setup asks only for the missing email when a profile already exists" {
    # Arrange
    mkdir -p "$(dirname "$profile_file")"
    echo work >"$profile_file"

    # Act
    run configure_profile <<<'developer@example.invalid'

    # Assert
    assert_success
    [[ "$output" != *'What kind of machine'* ]] || false
    [ "$(cat "$profile_file")" = work ]
    [ "$(git config --file "$HOME/.gitconfig-local" user.email)" = developer@example.invalid ]
}

@test "a saved profile with a blank local email still needs email setup" {
    # Arrange
    mkdir -p "$(dirname "$profile_file")"
    echo private >"$profile_file"
    git config --file "$HOME/.gitconfig-local" user.email '   '

    # Act
    run configure_profile <<<'private@example.invalid'

    # Assert
    assert_success
    [ "$(git config --file "$HOME/.gitconfig-local" user.email)" = private@example.invalid ]
}

@test "invalid selection and blank email are asked again" {
    # Act
    run configure_profile <<<$'wrong\n2\n   \ndeveloper@example.invalid'

    # Assert
    assert_success
    [ "$(cat "$profile_file")" = work ]
    [ "$(git config --global --includes user.email)" = developer@example.invalid ]
}

@test "closing input before selecting a profile saves neither a profile nor an email" {
    # Act
    run configure_profile </dev/null

    # Assert
    assert_failure
    assert_path_does_not_exist "$profile_file"
    assert_path_does_not_exist "$HOME/.gitconfig-local"
}

@test "closing input after selecting work but before entering an email saves neither setting" {
    # Act: choose Work, then close input at the email prompt.
    run configure_profile <<<'2'

    # Assert
    assert_failure
    assert_path_does_not_exist "$profile_file"
    assert_path_does_not_exist "$HOME/.gitconfig-local"
}

@test "no saved profile reads as private without questions or writes" {
    # Act
    run /bin/bash -ec 'source "$1/support/setup/output.sh"; source "$1/support/setup/machine-profile.sh"; load_machine_profile; printf "%s" "$DOTFILES_PROFILE"' bash "$dotfiles_dir"

    # Assert
    assert_success
    [ "$output" = private ]
    [ ! -e "$profile_file" ]
}

@test "an invalid saved profile is reported instead of silently choosing private" {
    # Arrange
    mkdir -p "$(dirname "$profile_file")"
    echo invalid >"$profile_file"

    # Act
    run configure_profile </dev/null

    # Assert
    assert_failure
    assert_output_contains 'Invalid machine profile'
}

@test "install configures the profile before sudo and skips questions on a second run" {
    # Arrange: sudo stops the installation with status 73.
    sudo() { exit 73; }
    export -f sudo

    # Act: a first installation chooses Work and enters an email.
    run /bin/bash "$dotfiles_dir/bin/install.sh" <<<$'y\n2\ndeveloper@example.invalid'

    # Assert: the work profile is saved before sudo stops the run.
    [ "$status" -eq 73 ]
    [ "$(cat "$profile_file")" = work ]

    # Act: a second installation answers only the confirmation.
    run /bin/bash "$dotfiles_dir/bin/install.sh" <<<'y'

    # Assert: sudo is reached without asking for the profile again.
    [ "$status" -eq 73 ]
    [[ "$output" != *'1) Private'* ]] || false
}

@test "declining installation does not configure a profile" {
    # Act
    run /bin/bash "$dotfiles_dir/bin/install.sh" <<<'n'

    # Assert
    assert_success
    [ ! -e "$profile_file" ]
}

@test "a failed Git config write does not save the selected work profile" {
    # Arrange
    printf '[broken\n' >"$HOME/.gitconfig-local"

    # Act
    run configure_profile <<<$'2\ndeveloper@example.invalid'

    # Assert
    assert_failure
    assert_output_contains 'Could not save the Git email'
    [ ! -e "$profile_file" ]
}

@test "reconfigure accepts a saved work profile without an email and reaches directory preparation" {
    # Arrange
    mkdir -p "$(dirname "$profile_file")"
    echo work >"$profile_file"
    rm -f "$HOME/.gitconfig-local"
    # Stop at directory preparation so no machine configuration is applied.
    printf 'prepare_home_directories() { exit 73; }\n' >"$HOME/.dotfiles/support/setup/home-directories.sh"

    # Act
    run /bin/bash "$dotfiles_dir/bin/reconfigure.sh" </dev/null

    # Assert
    assert_status 73
    assert_path_does_not_exist "$HOME/.gitconfig-local"
}

@test "update accepts a saved work profile without an email and reaches repository validation" {
    # Arrange
    mkdir -p "$(dirname "$profile_file")"
    echo work >"$profile_file"
    rm -f "$HOME/.gitconfig-local"
    # The fixture checkout is deliberately not a Git repository.

    # Act
    run /bin/bash "$dotfiles_dir/bin/update.sh" </dev/null

    # Assert
    assert_status 1
    assert_output_contains '~/.dotfiles is not a Git repository.'
    assert_path_does_not_exist "$HOME/.gitconfig-local"
}

@test "update rejects an invalid profile before repository or package operations" {
    # Arrange
    mkdir -p "$(dirname "$profile_file")"
    echo invalid >"$profile_file"

    # Act
    run /bin/bash "$dotfiles_dir/bin/update.sh" </dev/null

    # Assert
    assert_failure
    assert_output_contains 'Invalid machine profile'
    [[ "$output" != *'Pulling latest changes'* ]] || false
}

@test "reconfigure rejects an invalid profile before machine changes" {
    # Arrange
    mkdir -p "$(dirname "$profile_file")"
    echo invalid >"$profile_file"

    # Act
    run /bin/bash "$dotfiles_dir/bin/reconfigure.sh" </dev/null

    # Assert
    [ "$status" -eq 1 ]
    assert_output_contains 'Invalid machine profile'
}

@test "sourcing machine-profile does not read or overwrite the profile" {
    # Arrange
    mkdir -p "$(dirname "$profile_file")"
    echo invalid >"$profile_file"

    # Act
    run /bin/bash -ec 'source "$1/support/setup/output.sh"; DOTFILES_PROFILE=untouched; source "$1/support/setup/machine-profile.sh"; printf "%s" "$DOTFILES_PROFILE"' bash "$dotfiles_dir"

    # Assert
    assert_success
    [ "$output" = untouched ]
}
