call_update() {
    HOME="$test_home" XDG_CONFIG_HOME="$test_home/.config" HOMEBREW_PREFIX="$fixture" bash "$dotfiles_dir/bin/update.sh"
}

write_update_side_effects_that_must_not_run() {
    write_fake_binary git 'for argument in "$@"; do
    if [ "$argument" = "pull" ]; then
        touch "$UPDATE_SIDE_EFFECT_REACHED"
    fi
done
exec "$REAL_GIT" "$@"'

    write_fake_binary brew 'touch "$UPDATE_SIDE_EFFECT_REACHED"
exit 1'
}

assert_update_side_effect_was_not_reached() {
    [ ! -e "$UPDATE_SIDE_EFFECT_REACHED" ]
}

# Commits the real support/setup/ tree into the fixture repository, so update.sh's `source
# ~/.dotfiles/support/setup/...` calls resolve against the actual production files instead of
# a synthetic stand-in, proving the real wiring rather than a copy of it.
given_repository_with_real_setup_scripts() {
    cp -R "$dotfiles_dir/support" "$repository/support"
    find "$repository/support" -name ".DS_Store" -delete
    git -C "$repository" add support
    git -C "$repository" commit -qm "add support"
}

# Stands in for every external tool a full update.sh run drives (Homebrew, Composer, npm,
# pip via python3, agent-browser, the `skills` CLI via npx, Claude Code, and Ollama), each reporting an empty installed
# set so every *_cleanup function reports a clean state instead of touching real package managers.
given_every_external_tool_update_touches_is_faked() {
    write_fake_binary brew
    write_fake_binary npx
    write_fake_binary agent-browser
    given_fake_composer_reporting_installed '{"installed":[]}'
    given_fake_npm_reporting_installed '{"dependencies":{}}'
    given_fake_python_reporting_installed '[]'
    given_fake_claude '[]' ""
    given_skill_lock_file '{"skills":{}}'
    given_fake_ollama_listing ''
}

# The skills CLI reinstalls Clarity's whole repository on every add or update of it,
# so this fake brings the repository extras back the same way.
given_skills_update_restoring_clarity_extras() {
    write_fake_binary npx 'if [[ "$*" == *clarity* ]]; then
    clarity="$HOME/.claude/skills/clarity"
    mkdir -p "$clarity/references" "$clarity/scripts" "$clarity/website"
    touch "$clarity/SKILL.md" "$clarity/LICENSE" "$clarity/README.md"
fi'
}

assert_clarity_keeps_only_its_runtime_files() {
    [ "$(ls -A "$test_home/.claude/skills/clarity" | LC_ALL=C sort | tr '\n' ' ')" = "LICENSE SKILL.md references scripts " ]
}

# Sets a pinned version in the fixture repository's copy of a setup script, so a test does not
# depend on whatever version the real file pins today.
given_pinned_version() {
    local file="$1" variable="$2" version="$3"
    sed -i '' "s/^$variable=\".*\"$/$variable=\"$version\"/" "$repository/$file"
    git -C "$repository" commit -q --allow-empty -am "pin $variable to $version"
}

# Fake npm that reports no global packages and answers `npm view <package> time --json` with the
# given releases, each written as <version>:<days ago>, wrapped in a one-element array as npm 12 does.
given_npm_releases() {
    local package="$1"
    shift
    local entries="" release version days published
    for release in "$@"; do
        version="${release%%:*}"
        days="${release#*:}"
        published=$(/bin/date -u -v-"${days}"d +%Y-%m-%dT%H:%M:%S.000Z)
        entries="$entries\"$version\":\"$published\","
    done
    write_fake_binary npm "case \"\$*\" in
    'ls -g --depth=0 --json') printf '%s\n' '{\"dependencies\":{}}' ;;
    'view $package time --json') printf '%s\n' '[{${entries%,}}]' ;;
esac"
}

given_npm_release_lookup_fails() {
    write_fake_binary npm "case \"\$*\" in
    'ls -g --depth=0 --json') printf '%s\n' '{\"dependencies\":{}}' ;;
    view*) exit 1 ;;
esac"
}

assert_pinned_version() {
    local file="$1" variable="$2" version="$3"
    grep -qx "$variable=\"$version\"" "$repository/$file"
}

# A third-party marketplace named laravel, holding the laravel plugin in ./laravel, whose GitHub
# repository is a local bare repository: the test HOME's git config redirects https://github.com/
# to it, so no clone leaves the machine. A fake claude lists it next to Anthropic's official
# marketplace and records every call.
given_laravel_marketplace() {
    local upstream="$fixture/github/laravel/claude-code.git"
    local work="$fixture/marketplace-work"

    git init -q --bare "$upstream"
    git init -q -b main "$work"
    configure_test_repository "$work"
    mkdir -p "$work/.claude-plugin" "$work/laravel/skills"
    printf '%s\n' '{"plugins":[{"name":"laravel","source":"./laravel"}]}' > "$work/.claude-plugin/marketplace.json"
    echo "first" > "$work/laravel/skills/SKILL.md"
    git -C "$work" add .
    git -C "$work" commit -q -m first
    git -C "$work" push -q "$upstream" main
    git --git-dir="$upstream" symbolic-ref HEAD refs/heads/main

    git config --file "$test_home/.gitconfig" url."$fixture/github/".insteadOf "https://github.com/"

    write_fake_binary claude "case \"\$*\" in
    'plugin list --json') printf '%s\n' '[]' ;;
    'plugin marketplace list --json') printf '%s\n' '[{\"name\":\"laravel\",\"source\":\"git\",\"url\":\"https://github.com/laravel/claude-code.git\"},{\"name\":\"claude-plugins-official\",\"source\":\"git\",\"url\":\"https://github.com/anthropics/claude-plugins-official.git\"}]' ;;
esac"
}

# Anthropic's official marketplace at the URL the fake claude of given_laravel_marketplace lists,
# which must run first. It holds the three declared official plugins.
given_official_marketplace() {
    local upstream="$fixture/github/anthropics/claude-plugins-official.git"
    local work="$fixture/official-work" name

    git init -q --bare "$upstream"
    git init -q -b main "$work"
    configure_test_repository "$work"
    mkdir -p "$work/.claude-plugin"
    printf '%s\n' '{"plugins":[
        {"name":"claude-md-management","source":"./plugins/claude-md-management"},
        {"name":"typescript-lsp","source":"./plugins/typescript-lsp"},
        {"name":"context7","source":"./external_plugins/context7"}]}' > "$work/.claude-plugin/marketplace.json"
    for name in plugins/claude-md-management plugins/typescript-lsp external_plugins/context7; do
        mkdir -p "$work/$name/skills"
        echo "first" > "$work/$name/skills/SKILL.md"
    done
    git -C "$work" add .
    git -C "$work" commit -q -m first
    git -C "$work" push -q "$upstream" main
    git --git-dir="$upstream" symbolic-ref HEAD refs/heads/main
}

given_marketplace_listing_fails() {
    write_fake_binary claude "case \"\$*\" in
    'plugin list --json') printf '%s\n' '[]' ;;
    'plugin marketplace list --json') exit 1 ;;
esac"
}

# Runs update.sh once, so it records the upstream changes it sees, then ages those sightings by
# <days>, so the test's own run starts that far into the cooldown.
given_update_ran_days_ago() {
    local days="$1"
    call_update > /dev/null 2>&1 || true
    given_first_sightings_aged_by_days "$days"
    rm -f "$fake_bin"/*.calls
}
