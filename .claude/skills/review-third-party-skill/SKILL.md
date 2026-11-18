---
name: review-third-party-skill
description: Security review checklist for a third-party skill. Use before adding an entry to THIRD_PARTY_SKILLS in support/setup/claude/claude-skills.sh, or when asked whether an external skill is safe to install.
---

# Third-party skill review

Before adding an entry to `support/setup/claude/claude-skills.sh`, follow this manual checklist:

1. Read every file in the skill, including referenced Markdown and scripts, rather than only its description.
2. Search for network calls (`curl`, `fetch`, `requests`, `urllib`) and confirm every destination is expected.
3. Search for credential, cookie, or Keychain access (`security find-generic-password`, browser profiles,
   `~/.ssh`, `~/.aws`) and confirm a legitimate reason for it.
4. Check for hardcoded API keys, tokens, or passwords.
5. Look for instructions to ignore safety rules, hide actions, or behave differently for specific inputs.
6. List every shell command and tool the skill asks the agent to invoke. Assess the combined risk when file
   reads and network access appear together.
7. Check that referenced external URLs point to the expected domains.
8. Treat High or Critical findings from the CLI's Gen/Socket/Snyk audit as a reason to inspect carefully, not as
   a substitute for this review or a reliable signal by themselves. Those audits can be wrong or miss risks.

Adapted from [Anthropic's review checklist](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/enterprise#review-checklist).

Add each new `THIRD_PARTY_SKILLS` entry from `support/setup/claude/claude-skills.sh` to the third-party ignore
list in `.editorconfig`, so `bin/format.sh` leaves its scripts as upstream wrote them.
`tests/setup/claude/claude-skills.bats` fails while the two lists differ.
