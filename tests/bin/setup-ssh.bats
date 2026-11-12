#!/usr/bin/env bats

load ../support/test_helper

setup() {
    new_dotfiles_fixture
    export HOME="$fixture/home"
    mkdir -p "$HOME"
    given_fake_bin_on_path
    export SSH_AUTH_SOCK=""
    write_fake_binary ssh-keygen 'while [ "$1" != "-f" ]; do shift; done
printf "private key\n" > "$2"
printf "public key\n" > "$2.pub"'
    write_fake_binary ssh-agent 'echo "SSH_AUTH_SOCK=/test/agent; export SSH_AUTH_SOCK;"'
    write_fake_binary ssh-add
    write_fake_binary pbcopy 'cat > "$HOME/clipboard"'
}

teardown() {
    teardown_dotfiles_fixture
}

@test "creates a GitHub key, loads it into the keychain, and copies only the public key" {
    run /bin/bash "$dotfiles_dir/bin/setup-ssh.sh" "dev@example.com"

    assert_success
    assert_binary_called_with ssh-keygen "-t ed25519 -C dev@example.com -f $HOME/.ssh/id_ed25519"
    assert_binary_called_with ssh-add "--apple-use-keychain $HOME/.ssh/id_ed25519"
    assert_file_content "$HOME/clipboard" "public key"
    assert_output_contains "https://github.com/settings/keys"
}

@test "uses an existing SSH agent" {
    export SSH_AUTH_SOCK="/existing/agent"

    run /bin/bash "$dotfiles_dir/bin/setup-ssh.sh" "dev@example.com"

    assert_success
    assert_binary_not_called ssh-agent
}

@test "requires an email argument before making changes" {
    run /bin/bash "$dotfiles_dir/bin/setup-ssh.sh"

    assert_failure
    assert_output_contains "Usage:"
    assert_binary_not_called ssh-keygen
}

@test "refuses to overwrite an existing private or public key" {
    mkdir -p "$HOME/.ssh"
    for path in "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_ed25519.pub"; do
        printf 'existing key\n' > "$path"

        run /bin/bash "$dotfiles_dir/bin/setup-ssh.sh" "dev@example.com"

        assert_failure
        assert_output_contains "already exists"
        assert_file_content "$path" "existing key"
        assert_binary_not_called ssh-keygen
        rm "$path"
    done
}

@test "stops when key generation fails" {
    write_fake_binary ssh-keygen 'exit 1'

    run /bin/bash "$dotfiles_dir/bin/setup-ssh.sh" "dev@example.com"

    assert_failure
    assert_binary_not_called ssh-add
    assert_binary_not_called pbcopy
}

@test "does not report success or copy a key when adding it to the agent fails" {
    write_fake_binary ssh-add 'exit 1'

    run /bin/bash "$dotfiles_dir/bin/setup-ssh.sh" "dev@example.com"

    assert_failure
    assert_binary_not_called pbcopy
    assert_output_does_not_contain "https://github.com/settings/keys"
}
