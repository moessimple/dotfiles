#!/usr/bin/env bats

load ../support/test_helper

setup() {
    new_dotfiles_fixture
}

teardown() {
    teardown_dotfiles_fixture
}

# Fails and prints each step of bin/reconfigure.sh that bin/install.sh never calls. A step is a
# top-level line that consists only of a function name, the way both entry points call setup
# functions. Also fails when bin/reconfigure.sh has no such line, so it can never pass vacuously.
assert_install_runs_every_reconfigure_step() {
    local reconfigure_steps install_steps missing_steps
    reconfigure_steps="$(grep -E '^[a-z_]+$' "$dotfiles_dir/bin/reconfigure.sh" | sort -u)"
    if [ -z "$reconfigure_steps" ]; then
        echo "No steps found in bin/reconfigure.sh"
        return 1
    fi
    install_steps="$(grep -E '^[a-z_]+$' "$dotfiles_dir/bin/install.sh" | sort -u)"
    missing_steps="$(comm -23 <(printf '%s\n' "$reconfigure_steps") <(printf '%s\n' "$install_steps"))"
    if [ -n "$missing_steps" ]; then
        echo "Steps of bin/reconfigure.sh missing from bin/install.sh:"
        echo "$missing_steps"
        return 1
    fi
}

@test "install runs every step that reconfigure runs, so a fresh machine matches a reconfigured one" {
    assert_install_runs_every_reconfigure_step
}
