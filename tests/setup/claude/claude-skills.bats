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

@test "Clarity keeps only runtime files after installation and updates" {
    clarity_dir="$test_home/.claude/skills/clarity"
    mkdir -p "$clarity_dir/references" "$clarity_dir/scripts" "$test_home/.claude/skills/other"
    touch "$clarity_dir/SKILL.md" "$clarity_dir/LICENSE" "$clarity_dir/references/edit.md"
    touch "$clarity_dir/scripts/strip_markdown.py" "$clarity_dir/scripts/prose_stats.py"
    touch "$test_home/.claude/skills/other/keep"

    for pass in install update; do
        mkdir -p "$clarity_dir/site" "$clarity_dir/.github" "$clarity_dir/samples"
        touch "$clarity_dir/site/index.html" "$clarity_dir/.github/workflow.yml"
        touch "$clarity_dir/README.md" "$clarity_dir/scripts/validate_package.py"

        run run_setup_script "$target"

        assert_success
        [ "$(ls -A "$clarity_dir" | sort)" = "$(printf '%s\n' LICENSE SKILL.md references scripts | sort)" ]
        [ "$(ls -A "$clarity_dir/scripts" | sort)" = "$(printf '%s\n' prose_stats.py strip_markdown.py | sort)" ]
        [ -f "$clarity_dir/references/edit.md" ]
        [ -f "$test_home/.claude/skills/other/keep" ]
    done
}

@test "Clarity trimming leaves an incomplete installation untouched" {
    mkdir -p "$test_home/.claude/skills/clarity/site"
    touch "$test_home/.claude/skills/clarity/site/keep"

    run run_setup_script "$target"

    assert_success
    [ -f "$test_home/.claude/skills/clarity/site/keep" ]
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
    given_skill_lock_file '{"skills":{"code-review-dispatch":{},"debug":{},"outcome-writing":{},"pr":{},"quality":{},"review":{}}}'

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
