#!/usr/bin/env bats

load ../../support/test_helper

setup() {
    new_dotfiles_fixture
    commands_dir="$dotfiles_dir/home/.claude/commands"
    skills_dir="$dotfiles_dir/home/.claude/skills"
    shared_skills=(code-review-dispatch debug explain-changes outcome-writing pr quality review document-product characterize-behavior raise-quality-gate)
}

@test "legacy commands are replaced by shared skills" {
    # Assert
    assert_path_does_not_exist "$commands_dir/debug.md"
    assert_path_does_not_exist "$commands_dir/pr.md"
    assert_path_does_not_exist "$commands_dir/review.md"

    for skill in debug pr review; do
        assert_file_exists "$skills_dir/$skill/SKILL.md"
    done
}

@test "shared skill frontmatter contains no agent-specific fields" {
    # Assert
    for skill in "${shared_skills[@]}"; do
        frontmatter="$(awk 'NR == 1 && $0 == "---" { inside = 1; next } inside && $0 == "---" { exit } inside { print }' "$skills_dir/$skill/SKILL.md")"

        # Manual-only skills need Claude's disable-model-invocation; Codex gets the same
        # restriction from agents/openai.yaml (see the manual-only test below).
        if [ -f "$skills_dir/$skill/agents/openai.yaml" ]; then
            frontmatter="$(grep -v '^disable-model-invocation: true$' <<< "$frontmatter")"
        fi

        ! grep -Eq '^(argument-hint|disable-model-invocation|disallowed-tools|user-invocable):' <<< "$frontmatter" || false
    done
}

@test "manual-only skills are only invoked explicitly, in Claude and in Codex" {
    # Assert
    for skill in explain-changes pr review document-product characterize-behavior raise-quality-gate; do
        skill_dir="$skills_dir/$skill"

        grep -Fqx 'disable-model-invocation: true' "$skill_dir/SKILL.md" || return 1
        grep -Fqx '  allow_implicit_invocation: false' "$skill_dir/agents/openai.yaml" || return 1
    done
}

@test "shared skill instructions contain no Claude command expansion or named Claude agents" {
    # Assert
    for skill in code-review-dispatch debug explain-changes pr quality review document-product characterize-behavior raise-quality-gate; do
        skill_file="$skills_dir/$skill/SKILL.md"

        ! grep -Fq '$ARGUMENTS' "$skill_file" || false
        ! grep -Fq '!`' "$skill_file" || false
        ! grep -Fq 'agent-skills:code-reviewer' "$skill_file" || false
        ! grep -Fq 'laravel:laravel-simplifier' "$skill_file" || false
        ! grep -Fq 'general-purpose' "$skill_file" || false
    done
}

@test "shared workflows delegate reusable concerns to existing skills" {
    # Assert
    grep -Fq 'REQUIRED SUB-SKILL' "$skills_dir/debug/SKILL.md"
    grep -Fq '`diagnosing-bugs`' "$skills_dir/debug/SKILL.md"
    grep -Fq 'REQUIRED SUB-SKILL' "$skills_dir/pr/SKILL.md"
    grep -Fq '`outcome-writing`' "$skills_dir/pr/SKILL.md"
    grep -Fq '`code-review-dispatch`' "$skills_dir/pr/SKILL.md"
    grep -Fq 'REQUIRED SUB-SKILL' "$skills_dir/review/SKILL.md"
    grep -Fq '`code-review-dispatch`' "$skills_dir/review/SKILL.md"
    grep -Fq '`agent-skills:code-review-and-quality`' "$skills_dir/code-review-dispatch/SKILL.md"
    grep -Fq '`agent-skills:code-simplification`' "$skills_dir/code-review-dispatch/SKILL.md"
    grep -Fq '`spatie-laravel-php`' "$skills_dir/code-review-dispatch/SKILL.md"
    grep -Fq '`laravel-best-practices`' "$skills_dir/code-review-dispatch/SKILL.md"
    grep -Fq '`outcome-writing`' "$skills_dir/code-review-dispatch/SKILL.md"
}

@test "product skills work without the reference projects they were modelled on" {
    # Assert
    for skill in document-product characterize-behavior raise-quality-gate; do
        ! grep -rniE 'starter.?kit|/Users/|~/Code' "$skills_dir/$skill" || false
    done

    ! grep -rnE 'PRODUCT\.md|KNOWLEDGE_BASE\.md|document-product' "$skills_dir/characterize-behavior" || false
}

@test "the golden master reference is the same in both product skills that record it" {
    # Assert
    cmp "$skills_dir/characterize-behavior/references/golden-master.md" "$skills_dir/raise-quality-gate/references/golden-master.md"
}
