#!/usr/bin/env bats

load ../support/test_helper
load ../support/configuration_helper

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

    local script function_name
    while read -r script function_name; do
        printf '%s() {\n    printf "%%s\\n" "%s" >> "$INSTALL_STEPS_FILE"\n    if [[ "${INSTALL_WARN_STEP:-}" == "%s" ]]; then warn "Failed %s"; fi\n}\n' \
            "$function_name" "$function_name" "$function_name" "$function_name" \
            >"$repository/support/setup/$script"
    done <<'STEPS'
oh-my-zsh.sh install_oh_my_zsh
homebrew.sh install_homebrew
packages/homebrew-packages.sh install_homebrew_packages
packages/composer-packages.sh install_composer_packages
packages/npm-packages.sh install_npm_packages
packages/python-packages.sh install_python_packages
herd/herd-onboarding.sh wait_for_herd_onboarding
herd/herd-xdebug.sh install_herd_xdebug
tinkerbench.sh set_up_tinkerbench
claude/claude-skills.sh install_claude_skills
claude/claude-plugins.sh install_claude_plugins
codex/codex-skills.sh link_codex_skills
services.sh start_services
packages/ollama-models.sh install_ollama_models
STEPS
    printf '#!/bin/bash\nprintf "macos-defaults\\n" >> "$INSTALL_STEPS_FILE"\n' >"$repository/bin/macos-defaults.sh"
    chmod +x "$repository/bin/macos-defaults.sh"
}

teardown() {
    teardown_dotfiles_fixture
}

@test "installation applies configuration and runs dependent setup in order on repeated runs" {
    printf 'local settings' >"$test_home/.extra"
    local attempt
    for attempt in 1 2; do
        : >"$INSTALL_STEPS_FILE"

        run env HOME="$test_home" /bin/bash "$dotfiles_dir/bin/install.sh" <<<'y'

        assert_success
        assert_managed_dotfiles_are_linked
        assert_file_content "$test_home/.extra" "local settings"
        assert_file_content "$test_home/.config/dotfiles/profile" "work"
        assert_output_contains "Installation complete!"
        local step_name
        for step_name in sudo install_oh_my_zsh install_homebrew install_homebrew_packages \
            install_composer_packages install_npm_packages install_python_packages \
            wait_for_herd_onboarding install_herd_xdebug set_up_tinkerbench \
            install_claude_skills install_claude_plugins link_codex_skills \
            start_services install_ollama_models macos-defaults; do
            [ "$(grep -cxF "$step_name" "$INSTALL_STEPS_FILE")" -eq 1 ]
        done
        output="$(cat "$INSTALL_STEPS_FILE")"
        assert_output_contains_before install_homebrew install_homebrew_packages
        assert_output_contains_before install_homebrew_packages install_python_packages
        assert_output_contains_before install_homebrew_packages wait_for_herd_onboarding
        assert_output_contains_before wait_for_herd_onboarding install_herd_xdebug
        assert_output_contains_before install_herd_xdebug set_up_tinkerbench
        assert_output_contains_before install_claude_skills link_codex_skills
        assert_output_contains_before install_claude_plugins link_codex_skills
        assert_output_contains_before start_services install_ollama_models
        [ "$(tail -n 1 "$INSTALL_STEPS_FILE")" = macos-defaults ]
    done
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
    write_fake_binary ln 'if [[ "$3" == "$HOME/.exports" ]]; then exit 73; fi
exec /bin/ln "$@"'

    run env HOME="$test_home" /bin/bash "$dotfiles_dir/bin/install.sh" <<<'y'

    assert_status 73
    sort "$INSTALL_STEPS_FILE" >"$fixture/completed-steps"
    assert_file_content "$fixture/completed-steps" $'install_homebrew\ninstall_oh_my_zsh\nsudo'
    assert_output_does_not_contain "Installation complete!"
}
