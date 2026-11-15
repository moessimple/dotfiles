#!/usr/bin/env bats

load ../support/test_helper

setup() {
    new_dotfiles_fixture
    test_home="$fixture/home"
    repository="$test_home/.dotfiles"
    mkdir -p "$repository"
    cp -R "$dotfiles_dir/support" "$dotfiles_dir/home" "$repository/"
    given_fake_bin_on_path
    write_fake_binary sudo

    # Keep the real directory preparation and symlinks; isolate service and app setup.
    local script
    for script in codex/codex-skills.sh herd-onboarding.sh herd-debug-ini.sh tinkerbench/tinkerbench.sh services.sh; do
        printf 'touch "$HOME/%s.applied"\n' "$(basename "$script")" > "$repository/support/setup/$script"
    done
    printf 'echo "macOS settings must stay separate"\nexit 89\n' > "$repository/support/setup/macos/osx-defaults.sh"
}

teardown() {
    teardown_dotfiles_fixture
}

@test "reconfigure applies links and setup without applying macOS defaults or requesting sudo" {
    # Act
    run env HOME="$test_home" bash "$dotfiles_dir/bin/reconfigure.sh"

    # Assert
    assert_success
    [ "$(readlink "$test_home/.aliases")" = "$repository/home/.aliases" ]
    assert_file_exists "$test_home/herd-debug-ini.sh.applied"
    assert_file_exists "$test_home/herd-onboarding.sh.applied"
    assert_file_exists "$test_home/tinkerbench.sh.applied"
    assert_file_exists "$test_home/services.sh.applied"
    assert_file_exists "$test_home/codex-skills.sh.applied"
    assert_path_does_not_exist "$fake_bin/sudo.calls"
}
