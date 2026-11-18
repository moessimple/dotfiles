assert_managed_dotfiles_are_linked() {
    local source_path target_path
    while read -r source_path target_path; do
        [ -L "$test_home/$target_path" ]
        [ "$(readlink "$test_home/$target_path")" = "$repository/home/$source_path" ]
        [ -e "$test_home/$target_path" ]
    done <<'LINKS'
.aliases .aliases
.exports .exports
.functions .functions
.gemrc .gemrc
.gitconfig .gitconfig
.global-gitignore .global-gitignore
.hushlogin .hushlogin
.paths .paths
.zprofile .zprofile
.zshrc .zshrc
.claude/agents .claude/agents
.claude/commands .claude/commands
.claude/hooks .claude/hooks
.claude/rules .claude/rules
.claude/skills .claude/skills
.claude/settings.json .claude/settings.json
.claude/statusline.sh .claude/statusline.sh
.claude/AGENTS.md .claude/CLAUDE.md
.claude/AGENTS.md .codex/AGENTS.md
.config/ghostty/config .config/ghostty/config
.config/git/default-branch .config/git/default-branch
LINKS
}
