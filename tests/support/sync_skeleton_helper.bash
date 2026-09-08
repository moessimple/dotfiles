source "$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/test_helper.bash"

# Fixtures for tests/claude/skills/sync-skeleton/*.bats.
#
# The skill's scripts live under home/.claude/skills/sync-skeleton/scripts/ and
# compare a target project against the moessimple/laravel-starter-kit tree. These
# helpers build throwaway git repos under $BATS_TEST_TMPDIR so no test touches a
# real ~/Code clone or the network.

new_sync_skeleton_fixture() {
    new_dotfiles_fixture
    fixture="$(cd "$fixture" && pwd -P)"

    skill_dir="$dotfiles_dir/home/.claude/skills/sync-skeleton"
    preflight="$skill_dir/scripts/preflight.sh"
    fetch_kit="$skill_dir/scripts/fetch-kit.sh"
    classify="$skill_dir/scripts/classify.sh"
    profile="$skill_dir/reference/profiles/laravel-starter-kit.md"

    target="$fixture/project"
}

teardown_sync_skeleton_fixture() {
    teardown_dotfiles_fixture
}

# A committed, clean git repo carrying all three descendant markers the profile
# requires: boost.json, .ai/rules/, and an Inertia + Vue signature.
given_kit_descendant_project() {
    mkdir -p "$target/.ai/rules" "$target/resources/js"
    git init -q "$target"
    git -C "$target" config user.name "Sync Skeleton Tests"
    git -C "$target" config user.email "sync-skeleton-tests@example.com"
    printf '{}\n' > "$target/boost.json"
    printf '# actions\n' > "$target/.ai/rules/index.md"
    printf "import './app';\n" > "$target/resources/js/app.ts"
    printf '{"devDependencies":{"@inertiajs/vue3":"^1.0"}}\n' > "$target/package.json"
    git -C "$target" add -A
    git -C "$target" commit -qm "initial"
}

# Leaves an uncommitted change in the target working tree.
given_dirty_tree() {
    printf 'changed\n' >> "$target/boost.json"
}

# A directory that is not inside any git repository.
given_non_git_dir() {
    target="$fixture/not-a-repo"
    mkdir -p "$target"
}

# A clean git repo that is missing the descendant markers.
given_project_without_kit_markers() {
    mkdir -p "$target"
    git init -q "$target"
    git -C "$target" config user.name "Sync Skeleton Tests"
    git -C "$target" config user.email "sync-skeleton-tests@example.com"
    printf '# unrelated\n' > "$target/README.md"
    git -C "$target" add -A
    git -C "$target" commit -qm "initial"
}

run_preflight() {
    run bash "$preflight" laravel-starter-kit "$target"
}

# --- fetch-kit fixtures --------------------------------------------------------
#
# fetch-kit.sh reaches for $HOME/Code/laravel-starter-kit and, failing that,
# clones https://github.com/moessimple/laravel-starter-kit.git. These fixtures
# redirect $HOME to a fixture tree and rewrite that GitHub URL to a local bare
# repo via git's insteadOf, so both paths run offline.

kit_test_home() {
    printf '%s' "$fixture/home"
}

# Bare repo standing in for the GitHub remote, seeded with one commit on the
# given branch (default: main) and its HEAD pointed at that branch.
given_kit_remote() {
    local branch="${1:-main}"
    kit_remote="$fixture/remote/laravel-starter-kit.git"
    local seed="$fixture/seed"

    git init -q --bare "$kit_remote"
    git -C "$kit_remote" config uploadpack.allowFilter true
    git init -q "$seed"
    git -C "$seed" config user.name "Sync Skeleton Tests"
    git -C "$seed" config user.email "sync-skeleton-tests@example.com"
    git -C "$seed" checkout -q -b "$branch"
    printf 'kit\n' > "$seed/README.md"
    git -C "$seed" add -A
    git -C "$seed" commit -qm "kit initial"
    git -C "$seed" push -q "$kit_remote" "$branch"
    git -C "$kit_remote" symbolic-ref HEAD "refs/heads/$branch"

    mkdir -p "$(kit_test_home)"
    git config --file "$(kit_test_home)/.gitconfig" \
        "url.$kit_remote.insteadOf" "https://github.com/moessimple/laravel-starter-kit.git"
}

# A clone at $HOME/Code/laravel-starter-kit whose origin URL matches the profile
# regex (so fetch-kit.sh reuses it).
given_local_kit_clone() {
    local_kit_clone="$(kit_test_home)/Code/laravel-starter-kit"
    mkdir -p "$(dirname "$local_kit_clone")"
    git clone -q "$kit_remote" "$local_kit_clone"
    git -C "$local_kit_clone" remote set-url origin \
        "https://github.com/moessimple/laravel-starter-kit.git"
}

# Same location, but an origin URL that is not the starter kit (fetch-kit.sh must
# ignore it and clone fresh instead).
given_local_clone_with_unrelated_origin() {
    local_kit_clone="$(kit_test_home)/Code/laravel-starter-kit"
    mkdir -p "$(dirname "$local_kit_clone")"
    git clone -q "$kit_remote" "$local_kit_clone"
    git -C "$local_kit_clone" remote set-url origin \
        "https://github.com/someone-else/laravel-starter-kit-fork.git"
}

# Adds a second commit to the bare remote's default branch.
given_kit_remote_advanced() {
    local seed="$fixture/seed"
    printf 'more\n' >> "$seed/README.md"
    git -C "$seed" commit -qam "kit second"
    git -C "$seed" push -q "$kit_remote" HEAD
}

kit_clone_head() {
    git -C "$local_kit_clone" rev-parse HEAD
}

run_fetch_kit() {
    run env HOME="$(kit_test_home)" bash "$fetch_kit" laravel-starter-kit
}

# The last line fetch-kit.sh prints is always "<dir>\t<branch>\t<sha>"; a fresh
# clone from a local path also emits git's "--filter is ignored" warning first.
# Splits that result line into $fk_dir / $fk_branch / $fk_sha.
split_fetch_kit_result() {
    local last="${lines[$((${#lines[@]} - 1))]}"
    IFS=$'\t' read -r fk_dir fk_branch fk_sha <<< "$last"
}

# Runs preflight.sh capturing only its stderr, so a test can assert what the
# script routes there (the SPEC requires `git status --short` on stderr).
run_preflight_stderr() {
    run bash -c 'bash "$1" laravel-starter-kit "$2" 2>&1 1>/dev/null' _ "$preflight" "$target"
}
