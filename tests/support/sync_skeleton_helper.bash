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

# Runs preflight.sh capturing only its stderr, so a test can assert what the
# script routes there (the SPEC requires `git status --short` on stderr).
run_preflight_stderr() {
    run bash -c 'bash "$1" laravel-starter-kit "$2" 2>&1 1>/dev/null' _ "$preflight" "$target"
}
