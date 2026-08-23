#!/usr/bin/env bats

load ../../support/test_helper
load ../../support/setup_cleanup_helper

setup() {
    new_dotfiles_fixture
    given_fake_bin_on_path
    write_fake_binary npx
    test_home="$fixture/home"
    mkdir -p "$test_home"
    target="$dotfiles_dir/support/setup/claude/claude-skills.sh"
}

teardown() {
    teardown_dotfiles_fixture
}

@test "an installed skill not declared in claude-skills.sh is removed" {
    # Arrange
    given_skill_lock_file '{"skills":{"quality":{},"stale-skill":{}}}'

    # Act
    run call_cleanup_function "$target" claude_skills_cleanup

    # Assert
    assert_success
    assert_binary_called_with_substring npx "skills remove stale-skill --global -y --agent claude-code"
    assert_binary_not_called_with_substring npx "skills remove quality"
}

@test "a locally authored skill is not removed" {
    # Arrange
    given_skill_lock_file '{"skills":{"code-review-dispatch":{},"outcome-writing":{}}}'

    # Act
    run call_cleanup_function "$target" claude_skills_cleanup

    # Assert
    assert_success
    assert_binary_not_called_with_substring npx "skills remove"
}

@test "no undeclared skills reports a clean state without removing anything" {
    # Arrange
    given_skill_lock_file '{"skills":{"pdf":{}}}'

    # Act
    run call_cleanup_function "$target" claude_skills_cleanup

    # Assert
    assert_success
    assert_output_contains "No undeclared Claude Code skills found"
    assert_binary_not_called_with_substring npx "skills remove"
}

@test "an unreadable lock file skips cleanup instead of removing everything" {
    # Arrange
    given_unreadable_skill_lock_file

    # Act
    run call_cleanup_function "$target" claude_skills_cleanup

    # Assert
    assert_success
    assert_output_contains "Could not read"
    assert_binary_not_called_with_substring npx "skills remove"
}

@test "cleanup is skipped entirely when no lock file exists yet" {
    # Act
    run call_cleanup_function "$target" claude_skills_cleanup

    # Assert
    assert_success
    # If the `[ -f "$lock_file" ]` guard failed to return early, jq would still fail on the
    # missing file and this warning would appear, so its absence is what proves the guard fired.
    assert_output_does_not_contain "Could not read"
}
