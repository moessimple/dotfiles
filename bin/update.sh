#!/bin/bash

set -e # Exit on unhandled command failures

source "$(dirname -- "${BASH_SOURCE[0]}")/../support/setup/output.sh"

# Validate the saved profile before installing or removing packages.
source "$(dirname -- "${BASH_SOURCE[0]}")/../support/setup/machine-profile.sh"

echo ""
step "Updating dotfiles"
echo ""

# Runs first and refuses anything but a clean main checkout: the Claude CLI and skill
# updates below write to configuration tracked in this repository, and pulling over local
# changes can leave conflicted settings active. `git pull --autostash` can do exactly that
# and still exit 0.
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
# current formula versions. A package that cannot be updated is reported and the update
# goes on, as in install.sh.
step "Updating Homebrew packages"
brew update || warn "Could not update Homebrew itself, see the output above"
brew upgrade || warn "Could not upgrade every Homebrew package, see the output above"
brew bundle --file=~/.dotfiles/support/config/Brewfile \
    || warn "Some Brewfile packages failed to install, see the output above"
# Without --force this only prompts, and an unattended prompt does nothing.
brew bundle cleanup --force --file=~/.dotfiles/support/config/Brewfile \
    || warn "Could not remove every undeclared Homebrew package, see the output above"
# --prune=all: update, upgrade and bundle just downloaded every declared package they
# needed, so the whole download cache is stale. The default 120-day window lets casks
# like Docker.dmg pile up GBs between prunes.
brew cleanup --prune=all || warn "Could not prune Homebrew's download cache"
success "Homebrew packages processed"

# Install any global Composer packages newly added to the list, then update all
source ~/.dotfiles/support/setup/packages/composer-packages.sh
step "Updating global Composer packages"
if composer global update; then
    success "Composer packages updated"
else
    warn "Could not update the global Composer packages, see the output above"
fi
composer_packages_cleanup

# Install any global npm packages newly added to the list, then update all
source ~/.dotfiles/support/setup/packages/npm-packages.sh
step "Updating global npm packages"
if global_npm update -g --force; then
    success "npm packages updated"
else
    warn "Could not update the global npm packages, see the output above"
fi
npm_packages_cleanup
# npm never evicts its cache; every `npm`/`npx` run only adds to it. `verify` removes
# unreferenced content and trims the cache toward `cache-max`.
global_npm cache verify || warn "Could not verify the npm cache"

# Install any Python packages newly added to the list, then update all
source ~/.dotfiles/support/setup/packages/python-packages.sh
step "Updating Python packages"
if python_pip install --user --quiet --no-warn-script-location --upgrade "${PYTHON_PACKAGES[@]}"; then
    success "Python packages updated"
else
    warn "Could not update the Python packages, see the output above"
fi
python_packages_cleanup

# Install any Claude Code skills newly added to the list, then update them. A new upstream version of
# a skill or plugin waits out the same 3-day cooldown as Composer and npm
# (support/setup/claude/update-cooldown.sh).
source ~/.dotfiles/support/setup/claude/claude-skills.sh
source ~/.dotfiles/support/setup/claude/update-cooldown.sh
step "Updating Claude Code skills"
update_skills_after_cooldown
claude_skills_trim_clarity || warn "Could not trim Clarity's repository extras"
success "Claude Code skills updated"
claude_skills_cleanup

# Install any Claude Code plugins/MCP servers newly added to the list, then update them.
source ~/.dotfiles/support/setup/claude/claude-plugins.sh
step "Updating Claude Code plugins"
update_plugins_after_cooldown
success "Claude Code plugins updated"
claude_plugins_cleanup

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
    if ! newest=$(
        set -o pipefail
        global_npm view "$package" time --json 2>/dev/null \
            | jq -r --arg current "$current" '
            def numbers: split(".") | map(tonumber);
            .[0]
            | to_entries
            | map(select(.key | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")))
            | map(select((.value | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) <= now - 3 * 86400))
            | map(select((.key | numbers) > ($current | numbers)))
            | max_by(.key | numbers) | .key // empty'
    ); then
        warn "Could not check $package for a newer release"
        return 0
    fi
    [ -n "$newest" ] || return 0

    if ! sed -i '' "s/^$variable=\"$current\"$/$variable=\"$newest\"/" "$file"; then
        warn "Could not raise $package from $current to $newest in ${file#"$HOME/"}"
        return 0
    fi
    note "Raised $package from $current to $newest in ${file#"$HOME/"}. Release notes: https://www.npmjs.com/package/$package/v/$newest. Commit the change before the next update."
}

step "Checking pinned npm packages"
raise_npm_pin chrome-devtools-mcp ~/.dotfiles/support/setup/claude/claude-plugins.sh CHROME_DEVTOOLS_MCP_VERSION
raise_npm_pin skills ~/.dotfiles/support/setup/claude/claude-skills.sh SKILLS_CLI_VERSION

step "Applying dotfiles configuration"
~/.dotfiles/bin/reconfigure.sh || warn "Could not apply the dotfiles configuration, see the output above"

finish "Update complete!"
echo ""
note "Restart your terminal or run: exec zsh"
echo ""
