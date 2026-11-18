#!/usr/bin/env bats

load ../support/test_helper

setup() {
    new_dotfiles_fixture
    test_home="$fixture/home"
    repository="$test_home/.dotfiles"
    mkdir -p "$repository/bin"
    cp -R "$dotfiles_dir/support" "$dotfiles_dir/home" "$repository/"
    given_fake_bin_on_path
    write_fake_binary sudo

    # Keep the real directory preparation and symlinks; isolate service and app setup.
    given_setup_function_stub herd/herd-onboarding.sh wait_for_herd_onboarding
    given_setup_function_stub herd/herd-xdebug.sh install_herd_xdebug
    given_setup_function_stub tinkerbench.sh set_up_tinkerbench
    given_setup_function_stub services.sh start_services
    given_setup_function_stub codex/codex-skills.sh link_codex_skills
    printf 'echo "macOS settings must stay separate"\nexit 89\n' >"$repository/bin/macos-defaults.sh"
}

# Replaces a setup file in the fixture repository with one defining <function>, which records
# that it ran in $HOME/<file name>.applied.
given_setup_function_stub() {
    local script="$1" function_name="$2"
    printf '%s() { touch "$HOME/%s.applied"; }\n' "$function_name" "$(basename "$script")" \
        >"$repository/support/setup/$script"
}

teardown() {
    teardown_dotfiles_fixture
}

@test "reconfigure applies links and setup without applying macOS defaults or requesting sudo" {
    mkdir -p "$test_home/.claude/skills"
    touch "$test_home/.claude/skills/local-skill"

    # Act
    run env HOME="$test_home" bash "$dotfiles_dir/bin/reconfigure.sh"

    # Assert
    assert_success
    [ "$(readlink "$test_home/.aliases")" = "$repository/home/.aliases" ]
    assert_file_exists "$test_home/herd-xdebug.sh.applied"
    assert_file_exists "$test_home/herd-onboarding.sh.applied"
    assert_file_exists "$test_home/tinkerbench.sh.applied"
    assert_file_exists "$test_home/services.sh.applied"
    assert_file_exists "$test_home/codex-skills.sh.applied"
    assert_path_does_not_exist "$fake_bin/sudo.calls"
    assert_path_does_not_exist "$test_home/.claude/skills/local-skill"
    local directory
    for directory in Screenshots Temp Code .config/ghostty .config/git .claude .codex; do
        [ -d "$test_home/$directory" ]
    done
    assert_file_exists "$test_home/.extra"
    [[ "$output" == *"Preparing home directories"*"Home directories prepared"*"Creating symlinks"*"Symlinks created"* ]]
}

@test "sourcing home-directories leaves existing directories untouched" {
    mkdir -p "$test_home/.claude/skills"
    touch "$test_home/.claude/skills/local-skill"

    run env HOME="$test_home" /bin/bash -c 'source "$1"' bash \
        "$repository/support/setup/home-directories.sh"

    assert_success
    [ -z "$output" ]
    assert_file_exists "$test_home/.claude/skills/local-skill"
    assert_path_does_not_exist "$test_home/Screenshots"
}

@test "sourcing dotfile-links leaves existing files untouched" {
    printf 'local aliases\n' >"$test_home/.aliases"

    run env HOME="$test_home" /bin/bash -c 'source "$1"' bash \
        "$repository/support/setup/dotfile-links.sh"

    assert_success
    [ -z "$output" ]
    [ ! -L "$test_home/.aliases" ]
    [ "$(cat "$test_home/.aliases")" = "local aliases" ]
}
