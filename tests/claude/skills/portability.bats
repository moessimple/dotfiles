#!/usr/bin/env bats

load ../../support/test_helper

setup() {
    new_dotfiles_fixture
    commands_dir="$dotfiles_dir/home/.claude/commands"
    skills_dir="$dotfiles_dir/home/.claude/skills"
    shared_skills=(code-review-dispatch debug outcome-writing pr quality review)
}

@test "legacy commands are replaced by shared skills" {
    [ ! -e "$commands_dir/debug.md" ]
    [ ! -e "$commands_dir/pr.md" ]
    [ ! -e "$commands_dir/review.md" ]

    for skill in debug pr review; do
        [ -f "$skills_dir/$skill/SKILL.md" ]
    done
}

@test "shared skill frontmatter contains no agent-specific fields" {
    for skill in "${shared_skills[@]}"; do
        frontmatter="$(awk 'NR == 1 && $0 == "---" { inside = 1; next } inside && $0 == "---" { exit } inside { print }' "$skills_dir/$skill/SKILL.md")"

        ! grep -Eq '^(argument-hint|disable-model-invocation|disallowed-tools|user-invocable):' <<< "$frontmatter"
    done
}

@test "shared skill instructions contain no Claude command expansion or named Claude agents" {
    for skill in code-review-dispatch debug pr quality review; do
        skill_file="$skills_dir/$skill/SKILL.md"

        ! grep -Fq '$ARGUMENTS' "$skill_file"
        ! grep -Fq '!`' "$skill_file"
        ! grep -Fq 'agent-skills:code-reviewer' "$skill_file"
        ! grep -Fq 'laravel:laravel-simplifier' "$skill_file"
        ! grep -Fq 'general-purpose' "$skill_file"
    done
}

@test "shared workflows delegate reusable concerns to existing skills" {
    grep -Fq 'REQUIRED SUB-SKILL' "$skills_dir/debug/SKILL.md"
    grep -Fq '`diagnosing-bugs`' "$skills_dir/debug/SKILL.md"
    grep -Fq 'REQUIRED SUB-SKILL' "$skills_dir/pr/SKILL.md"
    grep -Fq '`outcome-writing`' "$skills_dir/pr/SKILL.md"
    grep -Fq 'REQUIRED SUB-SKILL' "$skills_dir/review/SKILL.md"
    grep -Fq '`code-review-dispatch`' "$skills_dir/review/SKILL.md"
    grep -Fq '`agent-skills:code-review-and-quality`' "$skills_dir/code-review-dispatch/SKILL.md"
    grep -Fq '`agent-skills:code-simplification`' "$skills_dir/code-review-dispatch/SKILL.md"
    grep -Fq '`spatie-laravel-php`' "$skills_dir/code-review-dispatch/SKILL.md"
    grep -Fq '`laravel-best-practices`' "$skills_dir/code-review-dispatch/SKILL.md"
    grep -Fq '`outcome-writing`' "$skills_dir/code-review-dispatch/SKILL.md"
}
