#!/bin/bash

set -e  # Exit on unhandled command failures

source "$(dirname -- "${BASH_SOURCE[0]}")/../support/setup/output.sh"

echo ""
step "Updating dotfiles"
echo ""

# Update dotfiles repo
#
# Check before any other step because the Claude CLI and skill updates modify
# live configuration tracked in this repository. Pulling over those changes can
# conflict with incoming updates. `git pull --autostash` is not a safe
# substitute: it can advance the branch, fail to reapply the stash and still
# exit 0 while conflicted settings remain active.
step "Pulling latest changes"
if ! git -C ~/.dotfiles rev-parse --git-dir &>/dev/null; then
    error "~/.dotfiles is not a Git repository."
fi

if ! current_branch=$(git -C ~/.dotfiles symbolic-ref --quiet --short HEAD); then
    error "~/.dotfiles is in detached HEAD state. Check out main, then run update again."
fi

if [ "$current_branch" != "main" ]; then
    error "~/.dotfiles is on '$current_branch'. Check out main, then run update again."
fi

if [ -n "$(git -C ~/.dotfiles status --porcelain)" ]; then
    echo ""
    git -C ~/.dotfiles status --short
    echo ""
    error "~/.dotfiles has uncommitted changes. Stash them (or commit and merge), then run update again."
fi
git -C ~/.dotfiles pull origin main
success "Dotfiles updated"

# Homebrew: update/upgrade first so bundle's own install and the cleanup below act on
# current formula versions.
step "Updating Homebrew packages"
brew update
brew upgrade
brew bundle --file=~/.dotfiles/support/config/Brewfile
# --force because without it this only prompts, and a prompt it cannot show makes it a no-op.
# All cleanups in this script remove undeclared things unattended, the declaration files
# are the only source of truth for what may be installed.
brew bundle cleanup --force --file=~/.dotfiles/support/config/Brewfile || true
# --prune=all: this runs weekly right after update/upgrade/bundle, so every declared
# package was just re-downloaded as needed and the entire download cache is stale.
# The default 120-day window lets casks like Docker.dmg accumulate GBs between prunes.
brew cleanup --prune=all
success "Homebrew packages updated"

# Install any global Composer packages newly added to the list, then update all
source ~/.dotfiles/support/setup/packages/composer-packages.sh
step "Updating global Composer packages"
composer global update
success "Composer packages updated"
composer_packages_cleanup

# Install any global npm packages newly added to the list, then update all
source ~/.dotfiles/support/setup/packages/npm-packages.sh
step "Updating global npm packages"
global_npm update -g --force
success "npm packages updated"
npm_packages_cleanup
# npm never evicts its own cache on its own; every `npm`/`npx` run only adds to it. `verify`
# garbage-collects unreferenced content and prunes it back toward `cache-max`, the npm
# counterpart to `brew cleanup` above.
global_npm cache verify

# Install any Python packages newly added to the list, then update all
source ~/.dotfiles/support/setup/packages/python-packages.sh
step "Updating Python packages"
python_pip install --user --quiet --no-warn-script-location --upgrade "${PYTHON_PACKAGES[@]}"
success "Python packages updated"
python_packages_cleanup

# Install any Claude Code skills newly added to the list, then update all
source ~/.dotfiles/support/setup/claude/claude-skills.sh
step "Updating Claude Code skills"
skills_cli update -g
claude_skills_trim_clarity || warn "Could not trim Clarity's repository extras"
success "Claude Code skills updated"
claude_skills_cleanup

# Install any Claude Code plugins/MCP servers newly added to the list, update the official ones
source ~/.dotfiles/support/setup/claude/claude-plugins.sh
source ~/.dotfiles/support/setup/claude/plugin-review.sh
# Plugins run with full user rights and are not committed, so a third-party plugin's changes are
# not pulled in unseen. Only Anthropic's official marketplace updates automatically. For every
# other plugin whose installed commit differs from its marketplace's GitHub HEAD, a link to the
# changes is printed. In a terminal, Claude's assessment follows and each update is applied on a
# yes; otherwise the command to apply it is printed, to run after a review. The installed commit
# comes from Claude Code's install record; the marketplace checkout is not used, because Claude
# Code can refresh it without updating the plugins.
report_plugin_changes() {
    local marketplaces
    # pipefail, so a failed listing is reported instead of reading as "no marketplaces to check".
    if ! marketplaces=$(set -o pipefail; claude plugin marketplace list --json 2>/dev/null \
        | jq -r '.[] | select(.name != "claude-plugins-official" and .url != null) | [.name, .url] | @tsv'); then
        warn "Could not list the plugin marketplaces, check third-party plugins for changes by hand"
        return 0
    fi

    local name url upstream plugin installed slug
    # The list arrives on fd 3, so stdin stays the terminal that answers review_plugin_update.
    while IFS=$'\t' read -r -u 3 name url; do
        [ -n "$name" ] || continue
        if ! upstream=$(git ls-remote "$url" HEAD 2>/dev/null | cut -f1) || [ -z "$upstream" ]; then
            warn "Could not check the $name marketplace for changes"
            continue
        fi

        for plugin in "${CLAUDE_PLUGINS[@]}"; do
            [ "${plugin#*@}" = "$name" ] || continue
            installed=$(installed_plugin_commit "$plugin") || installed=""
            if [ -z "$installed" ]; then
                warn "Could not read the installed commit of $plugin, check it with: claude plugin details $plugin"
                continue
            fi
            [ "$installed" = "$upstream" ] && continue

            case "$url" in
                https://github.com/*)
                    slug=${url#https://github.com/}
                    slug=${slug%.git}
                    warn "$plugin has changes: https://github.com/$slug/compare/$installed...$upstream"
                    ;;
                *)
                    warn "$plugin has changes from ${installed:0:7} to ${upstream:0:7} at $url"
                    ;;
            esac
            if [ -t 0 ]; then
                review_plugin_update "$plugin" "$name" "$url" "$installed" "$upstream"
            else
                echo "  After review: claude plugin marketplace update $name && claude plugin update $plugin"
            fi
        done
    done 3<<< "$marketplaces"
}

step "Updating Claude Code plugins"
for plugin in "${CLAUDE_PLUGINS[@]}"; do
    if [ "${plugin#*@}" = "claude-plugins-official" ]; then
        claude plugin update "$plugin" || true
    fi
done
success "Official Claude Code plugins updated"
report_plugin_changes
claude_plugins_cleanup

# Refresh links after Claude has updated both standalone and plugin-provided skills.
source ~/.dotfiles/support/setup/codex/codex-skills.sh

# Pull newer versions of the declared Ollama models, then remove undeclared ones
source ~/.dotfiles/support/setup/packages/ollama-models.sh
ollama_models_cleanup

# Raises a pinned npm package to its newest stable release that is at least 3 days old, the same
# cooldown its npx call enforces. The raised pin is an uncommitted change in this repository and
# takes effect on the next run, which refuses a dirty worktree, so it is committed first.
raise_npm_pin() {
    local package="$1" file="$2" variable="$3"
    local current newest
    current=$(sed -n "s/^$variable=\"\(.*\)\"$/\1/p" "$file")
    # pipefail, so a failed npm lookup is reported instead of reading as "no newer release".
    # npm 12 wraps `npm view --json` output in an array, hence the leading .[0].
    if ! newest=$(set -o pipefail; "${HOMEBREW_PREFIX:-/opt/homebrew}/bin/npm" view "$package" time --json 2>/dev/null \
        | jq -r --arg current "$current" '
            def numbers: split(".") | map(tonumber);
            .[0]
            | to_entries
            | map(select(.key | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")))
            | map(select((.value | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) <= now - 3 * 86400))
            | map(select((.key | numbers) > ($current | numbers)))
            | max_by(.key | numbers) | .key // empty'); then
        warn "Could not check $package for a newer release"
        return 0
    fi
    [ -n "$newest" ] || return 0

    sed -i '' "s/^$variable=\"$current\"$/$variable=\"$newest\"/" "$file"
    warn "Raised $package from $current to $newest in ${file#"$HOME/"}. Release notes: https://www.npmjs.com/package/$package/v/$newest. Commit the change before the next update."
}

step "Checking pinned npm packages"
raise_npm_pin chrome-devtools-mcp ~/.dotfiles/support/setup/claude/claude-plugins.sh CHROME_DEVTOOLS_MCP_VERSION
raise_npm_pin skills ~/.dotfiles/support/setup/claude/claude-skills.sh SKILLS_CLI_VERSION

echo ""
success "Update complete!"
echo ""
warn "Restart your terminal or run: exec zsh"
warn "This only updated package managers, run bin/reconfigure.sh too to apply symlink/setup script changes"
echo ""
