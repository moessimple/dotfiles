#!/usr/bin/env bats

load ../support/test_helper

setup() {
    new_dotfiles_fixture
    test_home="$fixture/home"
    mkdir -p "$test_home/.dotfiles/support" "$test_home/.oh-my-zsh"
    cp -R "$dotfiles_dir/support/git" "$test_home/.dotfiles/support/"
    cp "$dotfiles_dir/home/.exports" "$dotfiles_dir/home/.paths" \
        "$dotfiles_dir/home/.functions" "$dotfiles_dir/home/.aliases" "$test_home/"
    : >"$test_home/.oh-my-zsh/oh-my-zsh.sh"
    printf 'export EXTRA_WAS_LOADED=yes\n' >"$test_home/.extra"
    given_fake_bin_on_path
    write_fake_binary brew 'printf "export HOMEBREW_PREFIX=%q\n" "$TEST_BREW_PREFIX"'
    local tool directory
    for tool in ssh-add fzf direnv zoxide herd stty; do
        write_fake_binary "$tool"
    done
    for directory in .local/bin .composer/vendor/bin .gem/bin; do
        mkdir -p "$test_home/$directory"
    done
    mkdir -p "$fixture/sbin" "$fixture/opt/coreutils/libexec/gnubin" \
        "$fixture/opt/libxml2/bin" "$fixture/opt/ruby/bin"
    # Substitute only dependencies at fixed machine paths; the shell loading logic stays intact.
    sed "s|/opt/homebrew/bin/brew|$fake_bin/brew|g" "$dotfiles_dir/home/.zprofile" >"$test_home/.zprofile"
    sed "s|/Applications/Herd.app/Contents/Resources/config/shell/zshrc.zsh|$fixture/missing-herd.zsh|g" \
        "$dotfiles_dir/home/.zshrc" >"$test_home/.zshrc"
}

teardown() {
    teardown_dotfiles_fixture
}

@test "shell startup loads functions, Git helpers, aliases, and local settings together" {
    # Act
    run env HOME="$test_home" TEST_BREW_PREFIX="$fixture" PATH="/usr/bin:/bin" /bin/zsh -f -c '
        source "$HOME/.zprofile"
        source "$HOME/.zshrc"
        for name in p code quality switch sync search; do
            [[ "${+functions[$name]}" == 1 ]] || exit 1
        done
        [[ "$EXTRA_WAS_LOADED" == yes ]] || exit 1
        [[ "$EDITOR" == nano ]] || exit 1
        for hook in "${precmd_functions[@]}"; do "$hook"; done
        p "a test filter"
        alias php
    '

    # Assert
    assert_success
    assert_binary_called_with_args stty sane
    assert_output_contains "php='herd php'"
    assert_binary_called_with_args herd php -d memory_limit=2G ./vendor/bin/phpunit --testdox "a test filter"
}

@test "shell reload preserves PATH priority without adding duplicate entries" {
    # Act
    run env HOME="$test_home" TEST_BREW_PREFIX="$fixture" PATH="/usr/bin:/bin" /bin/zsh -f -c '
        source "$HOME/.zprofile"
        source "$HOME/.zshrc"
        first_path="$PATH"
        source "$HOME/.zprofile"
        source "$HOME/.zshrc"
        [[ "$PATH" == "$first_path" ]] || exit 1
        print -l -- "${path[@]:0:9}"
    '

    # Assert
    assert_success
    assert_output_equals "$test_home/Library/Application Support/Herd/bin/
$fixture/opt/ruby/bin
$fixture/opt/libxml2/bin
$fixture/opt/coreutils/libexec/gnubin
$fixture/sbin
$fixture/bin
$test_home/.gem/bin
$test_home/.composer/vendor/bin
$test_home/.local/bin"
}
