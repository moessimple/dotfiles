#!/usr/bin/env bats

load ../support/test_helper
load ../support/update_helper

setup() {
    new_dotfiles_fixture
    test_home="$fixture/home"
    repository="$test_home/.dotfiles"
    bin_dir="$fixture/bin"
    mkdir -p "$repository" "$bin_dir"
    export REAL_GIT="$(command -v git)"
    export UPDATE_SIDE_EFFECT_REACHED="$fixture/update-side-effect-reached"
    export PATH="$bin_dir:$PATH"
}

teardown() {
    teardown_dotfiles_fixture
}

@test "a feature branch is rejected before the repository or packages are updated" {
    create_test_repository
    git -C "$repository" switch -qc feature
    write_update_side_effects_that_must_not_run

    run call_update

    assert_failure
    assert_output_contains "is on 'feature'. Check out main"
    assert_current_branch feature
    assert_update_side_effect_was_not_reached
}

@test "detached HEAD is rejected before the repository or packages are updated" {
    create_test_repository
    git -C "$repository" switch -q --detach HEAD
    write_update_side_effects_that_must_not_run

    run call_update

    assert_failure
    assert_output_contains "is in detached HEAD state. Check out main"
    assert_head_is_detached
    assert_update_side_effect_was_not_reached
}

@test "a dirty main worktree is still rejected before the repository or packages are updated" {
    create_test_repository
    printf 'changed\n' > "$repository/tracked.txt"
    write_update_side_effects_that_must_not_run

    run call_update

    assert_failure
    assert_output_contains "has uncommitted changes"
    assert_current_branch main
    assert_worktree_is_dirty
    assert_update_side_effect_was_not_reached
}
