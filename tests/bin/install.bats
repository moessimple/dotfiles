#!/usr/bin/env bats

load ../support/test_helper
load ../support/configuration_helper

# Replaces a setup file in the fixture checkout with one function that appends its name to
# $INSTALL_STEPS_FILE and warns when INSTALL_WARN_STEP names it.
stub_setup_step() {
    local script="$1" function_name="$2"
    cat >"$repository/support/setup/$script" <<SCRIPT
$function_name() {
    printf '%s\\n' "$function_name" >>"\$INSTALL_STEPS_FILE"
    if [[ "\${INSTALL_WARN_STEP:-}" == "$function_name" ]]; then
        warn "Failed $function_name"
    fi
}
SCRIPT
}

setup() {
    new_dotfiles_fixture
    test_home="$fixture/home"
    repository="$test_home/.dotfiles"
    mkdir -p "$repository/bin" "$test_home/.config/dotfiles"
    cp -R "$dotfiles_dir/support" "$dotfiles_dir/home" "$repository/"
    printf 'work\n' >"$test_home/.config/dotfiles/profile"
    printf '[user]\nemail = tests@example.invalid\n' >"$test_home/.gitconfig-local"
    given_fake_bin_on_path
    export INSTALL_STEPS_FILE="$fixture/steps"
    write_fake_binary sudo 'printf "sudo\n" >> "$INSTALL_STEPS_FILE"'

    stub_setup_step oh-my-zsh.sh install_oh_my_zsh
    stub_setup_step homebrew.sh install_homebrew
    stub_setup_step packages/homebrew-packages.sh install_homebrew_packages
    stub_setup_step packages/composer-packages.sh install_composer_packages
    stub_setup_step packages/npm-packages.sh install_npm_packages
    stub_setup_step packages/python-packages.sh install_python_packages
    stub_setup_step herd/herd-onboarding.sh wait_for_herd_onboarding
    stub_setup_step herd/herd-xdebug.sh install_herd_xdebug
    stub_setup_step tinkerbench.sh set_up_tinkerbench
    stub_setup_step claude/claude-skills.sh install_claude_skills
    stub_setup_step claude/claude-plugins.sh install_claude_plugins
    stub_setup_step codex/codex-skills.sh link_codex_skills
    stub_setup_step services.sh start_services
    stub_setup_step packages/ollama-models.sh install_ollama_models
    cat >"$repository/bin/macos-defaults.sh" <<'SCRIPT'
#!/bin/bash
printf 'macos-defaults\n' >>"$INSTALL_STEPS_FILE"
SCRIPT
    chmod +x "$repository/bin/macos-defaults.sh"

    # Every recorded step of one complete installation, in byte order (LC_ALL=C sort).
    every_install_step='install_claude_plugins
install_claude_skills
install_composer_packages
install_herd_xdebug
install_homebrew
install_homebrew_packages
install_npm_packages
install_oh_my_zsh
install_ollama_models
install_python_packages
link_codex_skills
macos-defaults
set_up_tinkerbench
start_services
sudo
wait_for_herd_onboarding'
}

teardown() {
    teardown_dotfiles_fixture
}

@test "installation applies configuration, keeps local settings, and runs every setup step once" {
    printf 'local settings' >"$test_home/.extra"

    run env HOME="$test_home" /bin/bash "$dotfiles_dir/bin/install.sh" <<<'y'

    assert_success
    assert_output_contains "Installation complete!"
    assert_managed_dotfiles_are_linked
    assert_file_content "$test_home/.extra" "local settings"
    assert_file_content "$test_home/.config/dotfiles/profile" "work"
    LC_ALL=C sort "$INSTALL_STEPS_FILE" >"$fixture/completed-steps"
    assert_file_content "$fixture/completed-steps" "$every_install_step"
}

@test "installation runs dependent setup steps after their prerequisites and macOS defaults last" {
    run env HOME="$test_home" /bin/bash "$dotfiles_dir/bin/install.sh" <<<'y'
    assert_success

    run cat "$INSTALL_STEPS_FILE"

    assert_output_contains_before install_homebrew install_homebrew_packages
    assert_output_contains_before install_homebrew_packages install_python_packages
    assert_output_contains_before install_homebrew_packages wait_for_herd_onboarding
    assert_output_contains_before wait_for_herd_onboarding install_herd_xdebug
    assert_output_contains_before install_herd_xdebug set_up_tinkerbench
    assert_output_contains_before install_claude_skills link_codex_skills
    assert_output_contains_before install_claude_plugins link_codex_skills
    assert_output_contains_before start_services install_ollama_models
    [ "${lines[${#lines[@]} - 1]}" = macos-defaults ]
}

@test "a repeated installation keeps links and local settings and runs every setup step once again" {
    printf 'local settings' >"$test_home/.extra"
    run env HOME="$test_home" /bin/bash "$dotfiles_dir/bin/install.sh" <<<'y'
    assert_success
    : >"$INSTALL_STEPS_FILE"

    run env HOME="$test_home" /bin/bash "$dotfiles_dir/bin/install.sh" <<<'y'

    assert_success
    assert_output_contains "Installation complete!"
    assert_managed_dotfiles_are_linked
    assert_file_content "$test_home/.extra" "local settings"
    LC_ALL=C sort "$INSTALL_STEPS_FILE" >"$fixture/completed-steps"
    assert_file_content "$fixture/completed-steps" "$every_install_step"
}

@test "installation continues after a setup warning and reports failure at the end" {
    INSTALL_WARN_STEP=install_npm_packages run env HOME="$test_home" /bin/bash "$dotfiles_dir/bin/install.sh" <<<'y'

    assert_status 1
    assert_output_contains "Finished with 1 problem(s):"
    assert_output_contains "Failed install_npm_packages"
    assert_output_does_not_contain "Installation complete!"
    grep -qxF macos-defaults "$INSTALL_STEPS_FILE"
}

@test "installation stops before package setup when a managed link cannot be created" {
    write_fake_binary ln 'if [[ "${!#}" == "$HOME/.exports" ]]; then exit 73; fi
exec /bin/ln "$@"'

    run env HOME="$test_home" /bin/bash "$dotfiles_dir/bin/install.sh" <<<'y'

    assert_status 73
    sort "$INSTALL_STEPS_FILE" >"$fixture/completed-steps"
    assert_file_content "$fixture/completed-steps" $'install_homebrew\ninstall_oh_my_zsh\nsudo'
    assert_output_does_not_contain "Installation complete!"
}
