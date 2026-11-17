#!/usr/bin/env bats

load ../../support/test_helper

setup() {
    new_dotfiles_fixture
    commands_dir="$dotfiles_dir/home/.claude/commands"
    skills_dir="$dotfiles_dir/home/.claude/skills"
    shared_skills=(explain-changes pr document-product characterize-behavior raise-quality-gate)
}

@test "legacy commands are replaced by shared skills" {
    # Assert
    assert_path_does_not_exist "$commands_dir/debug.md"
    assert_path_does_not_exist "$commands_dir/pr.md"
    assert_path_does_not_exist "$commands_dir/review.md"

    assert_file_exists "$skills_dir/pr/SKILL.md"
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
    for skill in explain-changes pr document-product characterize-behavior raise-quality-gate; do
        skill_dir="$skills_dir/$skill"

        grep -Fqx 'disable-model-invocation: true' "$skill_dir/SKILL.md" || return 1
        grep -Fqx '  allow_implicit_invocation: false' "$skill_dir/agents/openai.yaml" || return 1
    done
}

@test "shared skill instructions contain no Claude command expansion or named Claude agents" {
    # Assert
    for skill in "${shared_skills[@]}"; do
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
    grep -Fq 'REQUIRED SUB-SKILL' "$skills_dir/pr/SKILL.md"
    grep -Fq '`clarity`' "$skills_dir/pr/SKILL.md"
    grep -Fq '`agent-skills:code-review-and-quality`' "$skills_dir/pr/SKILL.md"
    grep -Fq '`spatie-laravel-php`' "$skills_dir/pr/SKILL.md"
    grep -Fq '`laravel-best-practices`' "$skills_dir/pr/SKILL.md"
}

@test "product skills work without the reference projects they were modelled on" {
    # Assert
    for skill in document-product characterize-behavior raise-quality-gate; do
        ! grep -rniE 'starter.?kit|/Users/|~/Code' "$skills_dir/$skill" || false
    done

    ! grep -rnE 'PRODUCT\.md|KNOWLEDGE_BASE\.md|document-product' "$skills_dir/characterize-behavior" || false
}

@test "characterize-behavior and raise-quality-gate use feature documentation only where the project has it" {
    # Arrange
    condition='where the project documents its features'

    # Assert
    grep -Fq "$condition" "$skills_dir/characterize-behavior/SKILL.md"
    grep -Fq "$condition" "$skills_dir/raise-quality-gate/SKILL.md"
    ! grep -rnE 'PRODUCT\.md|KNOWLEDGE_BASE\.md|document-product' "$skills_dir/characterize-behavior" "$skills_dir/raise-quality-gate" || false
}

@test "raise-quality-gate extends the agent instructions section that document-product writes" {
    # Assert
    grep -Fqx '## Project knowledge' "$skills_dir/document-product/references/document-format.md"
    grep -Fq '`## Project knowledge`' "$skills_dir/raise-quality-gate/SKILL.md"
}

@test "document-product records confirmed rules in the format characterize-behavior searches for" {
    # Assert
    grep -Fqx 'Confirmed rules:' "$skills_dir/document-product/references/document-format.md"
    grep -Eq 'RULE-[0-9]{3}' "$skills_dir/document-product/references/document-format.md"
}

@test "characterize-behavior finds confirmed rules by the terms document-product writes" {
    # Assert
    grep -Fq '`Confirmed rules:`' "$skills_dir/characterize-behavior/SKILL.md"
    grep -Fq '`RULE-`' "$skills_dir/characterize-behavior/SKILL.md"
}

@test "raise-quality-gate reads the areas and acceptance tests that characterize-behavior records" {
    # Assert
    grep -Fq '## Areas' "$skills_dir/characterize-behavior/references/characterization-format.md"
    grep -Fq 'open / in progress / secured' "$skills_dir/characterize-behavior/references/characterization-format.md"
    grep -Fq '`## Areas`' "$skills_dir/raise-quality-gate/SKILL.md"
    grep -Fq '`secured`' "$skills_dir/raise-quality-gate/SKILL.md"
    grep -Fq "group('acceptance')" "$skills_dir/characterize-behavior/SKILL.md"
    grep -Fq "group('acceptance')" "$skills_dir/raise-quality-gate/SKILL.md"
    ! grep -rFq 'tests/Acceptance' "$skills_dir/characterize-behavior" "$skills_dir/raise-quality-gate" || false
}

@test "raise-quality-gate cleans up the same touched classes that characterize-behavior secures for a planned change" {
    # Assert
    grep -Fq '| any other argument: a planned change' "$skills_dir/characterize-behavior/SKILL.md"
    grep -Fq 'touched classes' "$skills_dir/characterize-behavior/SKILL.md"
    ! grep -rFq 'touched method' "$skills_dir/characterize-behavior" || false
    grep -Fq '| any other argument: a planned change' "$skills_dir/raise-quality-gate/SKILL.md"
    grep -Fq 'touched classes' "$skills_dir/raise-quality-gate/SKILL.md"
}

@test "document-product and characterize-behavior count area changes with the same git log command" {
    # Arrange
    changes_command='git log --since="12 months ago" --format=%H -- {paths} | sort -u | wc -l'

    # Assert
    grep -Fq "$changes_command" "$skills_dir/document-product/references/document-format.md"
    grep -Fq "$changes_command" "$skills_dir/characterize-behavior/references/characterization-format.md"
}

@test "raise-quality-gate reads the secured capabilities that characterize-behavior counts per area" {
    # Assert
    grep -Fq '| Capabilities |' "$skills_dir/characterize-behavior/references/characterization-format.md"
    grep -Fq '`Capabilities`' "$skills_dir/raise-quality-gate/references/record-format.md"
}

@test "document-product and characterize-behavior choose the next area by the same risk weights" {
    # Arrange
    weights='weight 3 for high, 2 for medium, and 1 for low risk; on a tie, the higher risk goes first'

    # Assert
    grep -Fq "$weights" "$skills_dir/document-product/references/document-format.md"
    grep -Fq "$weights" "$skills_dir/characterize-behavior/references/characterization-format.md"
}

@test "shared skill descriptions are valid YAML for strict parsers such as Codex" {
    # Assert
    for skill in "${shared_skills[@]}"; do
        description="$(grep -m1 '^description: ' "$skills_dir/$skill/SKILL.md")"

        # A plain (unquoted) scalar may not contain ": ", which strict YAML rejects.
        if ! grep -Eq '^description: ["'"'"'>|]' <<< "$description"; then
            ! grep -Fq ': ' <<< "${description#description: }" || return 1
        fi
    done
}
