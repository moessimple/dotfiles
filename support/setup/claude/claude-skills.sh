#!/bin/bash

# Third-party Claude Code skills installed via the `skills` CLI, one "owner/repo:skill" pair
# per entry (Bash 3.2, the /bin/bash shipped on macOS, has no associative arrays).
#
# Review additions with the third-party skill checklist in AGENTS.md.
THIRD_PARTY_SKILLS=(
    "addyosmani/clarity:clarity"
    "anthropics/skills:pdf"
    "anthropics/skills:skill-creator"
    "freekmurze/dotfiles:speeding-up-laravel-tests"
    "mattpocock/skills:diagnosing-bugs"
)

# The skills CLI installs, updates and removes the skills below with full user rights. It is pinned,
# and it runs through Homebrew's npx with a 3-day release-age cooldown, because it loads
# dependencies with version ranges that the pin alone does not fix. Herd's bundled npm 10 ignores
# --min-release-age. A raised version must itself be at least 3 days old, or npx refuses it.
SKILLS_CLI_VERSION="1.8.1"

SKILL_LOCK_FILE="$HOME/.agents/.skill-lock.json"

skills_cli() {
    "${HOMEBREW_PREFIX:-/opt/homebrew}/bin/npx" --min-release-age=3 --yes "skills@$SKILLS_CLI_VERSION" "$@"
}

# Clarity's root SKILL.md makes the CLI copy its whole repository, including the
# website. Keep only the runtime and license after every install/update.
trim_clarity_skill() {
    local skill_dir="$HOME/.claude/skills/clarity"
    [[ -f "$skill_dir/SKILL.md" ]] || return 0

    find "$skill_dir/." -mindepth 1 -maxdepth 1 \
        ! -name SKILL.md ! -name LICENSE ! -name references ! -name scripts \
        -exec rm -rf -- {} + || return 1

    [[ -d "$skill_dir/scripts" ]] || return 0
    find "$skill_dir/scripts/." -mindepth 1 -maxdepth 1 \
        ! -name strip_markdown.py ! -name prose_stats.py -exec rm -rf -- {} +
}

# === Install ===

install_claude_skills() {
    step "Installing Claude Code skills"
    # Only skills missing from the lock file are added, so a failed add is a real problem, and an
    # installed skill changes only through update_skills_after_cooldown. No lock file yet means
    # nothing is installed.
    local installed_skills="" entry repo skill
    if [[ -f "$SKILL_LOCK_FILE" ]] && ! installed_skills="$(jq -r '.skills // {} | keys[]' "$SKILL_LOCK_FILE" 2>/dev/null)"; then
        warn "Could not read $SKILL_LOCK_FILE, adding every declared skill"
        installed_skills=""
    fi
    for entry in "${THIRD_PARTY_SKILLS[@]}"; do
        repo="${entry%%:*}"
        skill="${entry#*:}"
        printf '%s\n' "$installed_skills" | grep -qxF "$skill" && continue
        skills_cli add "$repo" -s "$skill" --global -y --agent claude-code || warn "Could not install $skill"
    done
    trim_clarity_skill || warn "Could not trim Clarity's repository extras"
    success "Claude Code skills processed"
}

# === Update ===

# Prints the tree the skills CLI recorded for an installed skill, resolved in <checkout>. The lock
# file holds a tree hash for a skill in a subdirectory and a commit hash for one at the repository
# root; ^{tree} turns both into the tree that upstream is compared against.
print_installed_skill_tree() {
    local name="$1" checkout="$2" hash
    hash="$(jq -r --arg name "$name" '.skills[$name].skillFolderHash // empty' "$SKILL_LOCK_FILE" 2>/dev/null)" || return 1
    [[ -n "$hash" ]] || return 1
    git -C "$checkout" rev-parse --verify --quiet "$hash^{tree}"
}

# Updates every skill in the skills CLI's lock file whose upstream folder differs from the
# installed one and has passed the cooldown.
update_skills_after_cooldown() {
    local entries
    if ! entries="$(jq -r '.skills // {} | to_entries[]
            | [.key, .value.sourceUrl, (.value.skillPath | sub("/?SKILL\\.md$"; ""))] | @tsv' \
        "$SKILL_LOCK_FILE" 2>/dev/null)"; then
        warn "Could not read $SKILL_LOCK_FILE, skills not updated"
        return 0
    fi

    local name url skill_dir checkout upstream
    # The list arrives on fd 3, so the skills CLI in the loop cannot consume it from stdin.
    while IFS=$'\t' read -r -u 3 name url skill_dir; do
        [[ -n "$name" ]] || continue
        # shortcut: one clone per skill, even for skills from the same repository. Each takes about
        # a second; share them per repository if the list grows.
        checkout="$(mktemp -d)"
        if ! git clone --quiet --filter=blob:none --no-checkout "$url" "$checkout" 2>/dev/null \
            || ! upstream="$(git -C "$checkout" rev-parse --verify --quiet "HEAD:$skill_dir")"; then
            warn "Could not check $name, not updated"
        elif [[ "$upstream" != "$(print_installed_skill_tree "$name" "$checkout")" ]] && has_cooled_down "$name" "$upstream"; then
            skills_cli update "$name" -g || warn "Could not update $name"
        fi
        rm -rf "$checkout"
    done 3<<<"$entries"
}

# A new upstream version of a skill waits out the same 3-day cooldown as Composer and npm. Needs
# support/setup/claude/update-cooldown.sh sourced as well.
update_claude_skills() {
    step "Updating Claude Code skills"
    update_skills_after_cooldown
    trim_clarity_skill || warn "Could not trim Clarity's repository extras"
    success "Claude Code skill updates processed"
}

# === Clean up ===

# Removes any globally installed skill that isn't in THIRD_PARTY_SKILLS, the Claude Code
# equivalent of `brew bundle cleanup --force`. That includes skills added by hand with
# `npx skills add` (or by Claude on request), even when only their entry in the lock file
# is left and the folder is already gone.
clean_up_claude_skills() {
    [[ -f "$SKILL_LOCK_FILE" ]] || return 0

    step "Checking for undeclared Claude Code skills"

    local declared_names=() entry
    for entry in "${THIRD_PARTY_SKILLS[@]}"; do
        declared_names+=("${entry#*:}")
    done

    local installed
    if ! installed="$(jq -r '.skills // {} | keys[]' "$SKILL_LOCK_FILE" 2>/dev/null)"; then
        warn "Could not read $SKILL_LOCK_FILE, skipping cleanup"
        return 0
    fi

    local name found_undeclared=0
    while IFS= read -r name; do
        [[ -n "$name" ]] || continue
        printf '%s\n' "${declared_names[@]}" | grep -qxF "$name" && continue

        found_undeclared=1
        note "Removing undeclared skill: $name (not in claude-skills.sh)"
        # No --agent: with it, the CLI removes only that agent's copy and keeps the lock
        # entry, so the skill stays listed as installed. -y keeps the run unattended.
        skills_cli remove "$name" --global -y 2>/dev/null || warn "Could not remove $name, remove it manually"
    done <<<"$installed"

    if ((found_undeclared == 0)); then
        success "No undeclared Claude Code skills found"
    fi
}
