#!/usr/bin/env bats

load ../support/test_helper
load ../support/configuration_helper

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
    assert_managed_dotfiles_are_linked
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
    assert_output_contains_before "Preparing home directories" "Home directories prepared"
    assert_output_contains_before "Home directories prepared" "Creating symlinks"
    assert_output_contains_before "Creating symlinks" "Symlinks created"
}

@test "reconfigure replaces drifted managed paths and preserves local and unmanaged data" {
    # Arrange: real directories, a local file, and wrong or broken links where managed links belong.
    local directory
    for directory in agents commands hooks rules skills; do
        mkdir -p "$test_home/.claude/$directory"
        touch "$test_home/.claude/$directory/local-copy"
    done
    mkdir -p "$test_home/.codex"
    printf 'local aliases' >"$test_home/.aliases"
    ln -s "$fixture/missing" "$test_home/.paths"
    ln -s "$fixture/wrong-instructions" "$test_home/.codex/AGENTS.md"
    # Machine-local and unmanaged files that reconfigure must keep.
    printf 'local settings' >"$test_home/.extra"
    printf 'local identity' >"$test_home/.gitconfig-local"
    printf 'unmanaged data' >"$test_home/unmanaged"

    # Act
    run env HOME="$test_home" /bin/bash "$dotfiles_dir/bin/reconfigure.sh"

    # Assert
    assert_success
    assert_managed_dotfiles_are_linked
    for directory in agents commands hooks rules skills; do
        assert_path_does_not_exist "$test_home/.claude/$directory/local-copy"
    done
    assert_file_content "$test_home/.extra" "local settings"
    assert_file_content "$test_home/.gitconfig-local" "local identity"
    assert_file_content "$test_home/unmanaged" "unmanaged data"
}

@test "a repeated reconfigure replaces its own links without deleting repository files through them" {
    # Arrange: after the first run, ~/.claude/skills is a link into the repository.
    printf 'repository skill' >"$repository/home/.claude/skills/source-sentinel"
    printf 'local settings' >"$test_home/.extra"
    run env HOME="$test_home" /bin/bash "$dotfiles_dir/bin/reconfigure.sh"
    assert_success

    # Act
    run env HOME="$test_home" /bin/bash "$dotfiles_dir/bin/reconfigure.sh"

    # Assert
    assert_success
    assert_managed_dotfiles_are_linked
    assert_file_content "$repository/home/.claude/skills/source-sentinel" "repository skill"
    assert_file_content "$test_home/.extra" "local settings"
}

@test "a directory preparation failure stops reconfigure before links or dependent setup" {
    touch "$test_home/Screenshots"

    run env HOME="$test_home" /bin/bash "$dotfiles_dir/bin/reconfigure.sh"

    assert_failure
    [ ! -L "$test_home/.aliases" ]
    assert_path_does_not_exist "$test_home/herd-onboarding.sh.applied"
    assert_path_does_not_exist "$test_home/codex-skills.sh.applied"
    assert_output_does_not_contain "Configuration applied"
}

@test "a symlink failure stops reconfigure before dependent setup" {
    write_fake_binary ln 'if [[ "${!#}" == "$HOME/.exports" ]]; then exit 73; fi
exec /bin/ln "$@"'

    run env HOME="$test_home" /bin/bash "$dotfiles_dir/bin/reconfigure.sh"

    assert_status 73
    assert_path_does_not_exist "$test_home/herd-onboarding.sh.applied"
    assert_path_does_not_exist "$test_home/codex-skills.sh.applied"
    assert_output_does_not_contain "Configuration applied"
}
