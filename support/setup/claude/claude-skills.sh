#!/bin/bash

# Skills written directly in this repo, living in home/.claude/skills/ rather than being
# installed through this script. This is the source of truth claude_skills_cleanup uses to
# tell them apart from third-party skills below. Keep it in sync with what's actually there.
LOCAL_SKILLS=(
    code-review-dispatch
    outcome-writing
    quality
)

# Third-party Claude Code skills installed via the `skills` CLI, one "owner/repo:skill" pair
# per entry (Bash 3.2, the /bin/bash shipped on macOS, has no associative arrays).
#
# Before adding a new entry below, review the skill first (adapted from
# Anthropic's own vetting checklist for Agent Skills):
#   1. Read every file in the skill (SKILL.md, referenced markdown, scripts),
#      not just the description.
#   2. Search for network calls (curl, fetch, requests, urllib) and confirm
#      any destination is expected.
#   3. Search for credential, cookie, or keychain access (security
#      find-generic-password, browser profile paths, ~/.ssh, ~/.aws) and
#      confirm there is a legitimate reason for it.
#   4. Check for hardcoded API keys, tokens, or passwords in the skill's
#      files.
#   5. Look for instructions that tell Claude to ignore safety rules, hide
#      actions from the user, or behave differently based on specific
#      inputs.
#   6. List every bash command and tool the skill instructs Claude to
#      invoke, and weigh the combined risk when file reads and network
#      access show up together.
#   7. If the skill references external URLs, confirm they point to the
#      expected domain.
#   8. Treat a High or Critical rating from the CLI's own Gen/Socket/Snyk
#      audit as a prompt to do this review carefully, not as a substitute
#      for it or a reliable signal by itself; it has been both wrong and
#      silent on real risk in practice.
# Source: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/enterprise#review-checklist
#
# TODO: this checklist is manual today and depends on remembering to run it.
# Investigate automating it, e.g. a pre-install check that scans a skill's
# source for network calls, credential/keychain/cookie access, and hardcoded
# secrets before `npx skills add` runs, so review does not rely on memory.
THIRD_PARTY_SKILLS=(
    "anthropics/skills:frontend-design"
    "anthropics/skills:pdf"
    "anthropics/skills:skill-creator"
    "wshobson/agents:bash-defensive-patterns"
    "vercel-labs/agent-skills:web-design-guidelines"
    "vercel-labs/skills:find-skills"
    "freekmurze/dotfiles:speeding-up-laravel-tests"
    "benedictking/context7-auto-research:context7-auto-research"
    "mattpocock/skills:diagnosing-bugs"
    "mattpocock/skills:improve-codebase-architecture"
    "mattpocock/skills:codebase-design"
    "laravel/boost:laravel-best-practices"
    "spatie/guidelines-skills:spatie-laravel-php"
    "spatie/guidelines-skills:spatie-security"
    "spatie/guidelines-skills:spatie-javascript"
    "github/awesome-copilot:sql-optimization"
    "wondelai/skills:working-with-legacy-code"
)

# Install each entry in THIRD_PARTY_SKILLS via `npx skills add`; failures are
# downgraded to warnings so the remaining skills can still be processed.
step "Installing Claude Code skills"
for entry in "${THIRD_PARTY_SKILLS[@]}"; do
    repo="${entry%%:*}"
    skill="${entry#*:}"
    npx skills add "$repo" -s "$skill" --global -y --agent claude-code 2>/dev/null || warn "$skill already installed or failed"
done
success "Claude Code skills processed"

# Removes any globally installed skill that isn't in THIRD_PARTY_SKILLS or LOCAL_SKILLS. This
# is the Claude Code equivalent of `brew bundle cleanup --force`: it catches skills added by
# hand with `npx skills add` (or by Claude on request) and never recorded here, such as the
# mvanhorn/last30days-skill install that lingered in ~/.agents/.skill-lock.json after its
# folder was removed.
claude_skills_cleanup() {
    local lock_file=~/.agents/.skill-lock.json
    [ -f "$lock_file" ] || return 0

    step "Checking for undeclared Claude Code skills"

    local declared_names=()
    for entry in "${THIRD_PARTY_SKILLS[@]}"; do
        declared_names+=("${entry#*:}")
    done
    declared_names+=("${LOCAL_SKILLS[@]}")

    # The assignment is kept out of `local` so a missing jq or an unreadable lock file surfaces
    # instead of looking like an empty list and reporting a green run over a broken one.
    local installed
    if ! installed=$(jq -r '.skills // {} | keys[]' "$lock_file" 2>/dev/null); then
        warn "Could not read $lock_file, skipping cleanup"
        return 0
    fi

    local name found_undeclared=0
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        if ! printf '%s\n' "${declared_names[@]}" | grep -qxF "$name"; then
            found_undeclared=1
            warn "Removing undeclared skill: $name (not in claude-skills.sh)"
            # Same -y and --agent as the install above, otherwise the CLI asks which agent to
            # remove from and waits for an answer in the middle of an unattended update.
            npx skills remove "$name" --global -y --agent claude-code 2>/dev/null || warn "Could not remove $name, remove it manually"
        fi
    done <<< "$installed"

    # An `if`, not `&&`, which would return 1 after a removal and trip `set -e` in bin/update.sh
    if [ "$found_undeclared" -eq 0 ]; then
        success "No undeclared Claude Code skills found"
    fi
}
