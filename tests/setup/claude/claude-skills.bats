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
    given_setup_script_pinned SKILLS_CLI_VERSION 1.7.6
}

teardown() {
    teardown_dotfiles_fixture
}

@test "sourcing claude-skills.sh only defines its functions and runs no skills CLI command" {
    # Act
    run run_setup_script "$target"

    # Assert
    assert_success
    [ -z "$output" ]
    assert_binary_not_called npx
}

@test "Clarity installation keeps only its runtime files and leaves other skills untouched" {
    # Arrange: Clarity runtime files, non-runtime files from its repository, and another skill.
    clarity_dir="$test_home/.claude/skills/clarity"
    mkdir -p "$clarity_dir/references" "$clarity_dir/scripts" "$test_home/.claude/skills/other"
    touch "$clarity_dir/SKILL.md" "$clarity_dir/LICENSE" "$clarity_dir/references/edit.md"
    touch "$clarity_dir/scripts/strip_markdown.py" "$clarity_dir/scripts/prose_stats.py"
    touch "$test_home/.claude/skills/other/keep"
    mkdir -p "$clarity_dir/site" "$clarity_dir/.github" "$clarity_dir/samples"
    touch "$clarity_dir/site/index.html" "$clarity_dir/.github/workflow.yml"
    touch "$clarity_dir/README.md" "$clarity_dir/scripts/validate_package.py"

    # Act
    run call_setup_function "$target" install_claude_skills

    # Assert
    assert_success
    [ "$(ls -A "$clarity_dir" | sort)" = "$(printf '%s\n' LICENSE SKILL.md references scripts | sort)" ]
    [ "$(ls -A "$clarity_dir/scripts" | sort)" = "$(printf '%s\n' prose_stats.py strip_markdown.py | sort)" ]
    assert_file_exists "$clarity_dir/references/edit.md"
    assert_file_exists "$test_home/.claude/skills/other/keep"
}

@test "a repeated Clarity installation removes non-runtime files that reappear" {
    # Arrange: a completed installation, after which an update restores non-runtime files.
    clarity_dir="$test_home/.claude/skills/clarity"
    mkdir -p "$clarity_dir/references" "$clarity_dir/scripts" "$test_home/.claude/skills/other"
    touch "$clarity_dir/SKILL.md" "$clarity_dir/LICENSE" "$clarity_dir/references/edit.md"
    touch "$clarity_dir/scripts/strip_markdown.py" "$clarity_dir/scripts/prose_stats.py"
    touch "$test_home/.claude/skills/other/keep"
    run call_setup_function "$target" install_claude_skills
    assert_success
    mkdir -p "$clarity_dir/site" "$clarity_dir/.github" "$clarity_dir/samples"
    touch "$clarity_dir/site/index.html" "$clarity_dir/.github/workflow.yml"
    touch "$clarity_dir/README.md" "$clarity_dir/scripts/validate_package.py"

    # Act
    run call_setup_function "$target" install_claude_skills

    # Assert
    assert_success
    [ "$(ls -A "$clarity_dir" | sort)" = "$(printf '%s\n' LICENSE SKILL.md references scripts | sort)" ]
    [ "$(ls -A "$clarity_dir/scripts" | sort)" = "$(printf '%s\n' prose_stats.py strip_markdown.py | sort)" ]
    assert_file_exists "$clarity_dir/references/edit.md"
    assert_file_exists "$test_home/.claude/skills/other/keep"
}

@test "Clarity trimming leaves an incomplete installation untouched" {
    # Arrange
    mkdir -p "$test_home/.claude/skills/clarity/site"
    touch "$test_home/.claude/skills/clarity/site/keep"

    # Act
    run call_setup_function "$target" install_claude_skills

    # Assert
    assert_success
    assert_file_exists "$test_home/.claude/skills/clarity/site/keep"
}

@test "skills are installed through the pinned skills CLI with a release-age cooldown" {
    # Act
    run call_setup_function "$target" install_claude_skills

    # Assert
    assert_success
    assert_binary_called_with_substring npx "--min-release-age=3 --yes skills@1.7.6 add"
}

@test "a declared skill that is already installed is not added again" {
    # Arrange
    given_skill_lock_file '{"skills":{"pdf":{}}}'

    # Act
    run call_setup_function "$target" install_claude_skills

    # Assert
    assert_success
    assert_binary_not_called_with_substring npx "add anthropics/skills -s pdf "
    assert_binary_called_with_substring npx "add mattpocock/skills -s diagnosing-bugs "
}

@test "a skill that cannot be added is reported as a warning" {
    # Arrange
    given_skills_cli_failing_to_add_skills

    # Act
    run call_setup_function "$target" install_claude_skills

    # Assert
    assert_success
    assert_output_contains "WARN: Could not install diagnosing-bugs"
}

@test "skill installation warns and retries declared skills when the lock file is invalid" {
    # Arrange
    given_unreadable_skill_lock_file

    # Act
    run call_setup_function "$target" install_claude_skills

    # Assert
    assert_success
    assert_output_contains "WARN: Could not read"
    assert_binary_called_with_substring npx "add anthropics/skills -s pdf "
    assert_binary_called_with_substring npx "add mattpocock/skills -s diagnosing-bugs "
}

@test "an installed skill not declared in claude-skills.sh is removed" {
    # Arrange
    given_skill_lock_file '{"skills":{"diagnosing-bugs":{},"stale-skill":{}}}'

    # Act
    run call_cleanup_function "$target" clean_up_claude_skills

    # Assert
    assert_success
    assert_binary_called_with_substring npx "remove stale-skill --global -y"
    assert_binary_not_called_with_substring npx "remove stale-skill --global -y --agent"
    assert_binary_not_called_with_substring npx "remove diagnosing-bugs"
}

@test "no undeclared skills reports a clean state without removing anything" {
    # Arrange
    given_skill_lock_file '{"skills":{"pdf":{}}}'

    # Act
    run call_cleanup_function "$target" clean_up_claude_skills

    # Assert
    assert_success
    assert_output_contains "No undeclared Claude Code skills found"
    assert_binary_not_called_with_substring npx " remove "
}

@test "an unreadable lock file skips cleanup instead of removing everything" {
    # Arrange
    given_unreadable_skill_lock_file

    # Act
    run call_cleanup_function "$target" clean_up_claude_skills

    # Assert
    assert_success
    assert_output_contains "Could not read"
    assert_binary_not_called_with_substring npx " remove "
}

@test "cleanup is skipped entirely when no lock file exists yet" {
    # Act
    run call_cleanup_function "$target" clean_up_claude_skills

    # Assert
    assert_success
    # If the `[ -f "$lock_file" ]` guard failed to return early, jq would still fail on the
    # missing file and this warning would appear, so its absence is what proves the guard fired.
    assert_output_does_not_contain "Could not read"
}
