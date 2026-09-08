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
    plan_manifest="$skill_dir/scripts/plan-manifest.sh"
    apply_new_files="$skill_dir/scripts/apply-new-files.sh"
    scan_imports="$skill_dir/scripts/scan-imports.sh"
    run_tests_sh="$skill_dir/scripts/run-tests.sh"
    reconcile="$skill_dir/scripts/reconcile-manifests.sh"

    target="$fixture/project"
}

teardown_sync_skeleton_fixture() {
    teardown_dotfiles_fixture
}

# --- preflight fixtures ------------------------------------------------------

# A committed, clean repo carrying the descendant markers preflight requires:
# boost.json, .ai/rules/, and an Inertia + Vue signature.
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

# A clean repo missing the descendant markers.
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

# Runs preflight.sh capturing only its stderr.
run_preflight_stderr() {
    run bash -c 'bash "$1" laravel-starter-kit "$2" 2>&1 1>/dev/null' _ "$preflight" "$target"
}

# --- fetch-kit fixtures ----------------------------------------------------
#
# fetch-kit.sh reaches for $HOME/Code/laravel-starter-kit and, failing that,
# clones https://github.com/moessimple/laravel-starter-kit.git. These fixtures
# redirect $HOME and rewrite that URL to a local bare repo via git insteadOf, so
# both paths run offline.

kit_test_home() {
    printf '%s' "$fixture/home"
}

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

given_local_kit_clone() {
    local_kit_clone="$(kit_test_home)/Code/laravel-starter-kit"
    mkdir -p "$(dirname "$local_kit_clone")"
    git clone -q "$kit_remote" "$local_kit_clone"
    git -C "$local_kit_clone" remote set-url origin \
        "https://github.com/moessimple/laravel-starter-kit.git"
}

given_local_clone_with_unrelated_origin() {
    local_kit_clone="$(kit_test_home)/Code/laravel-starter-kit"
    mkdir -p "$(dirname "$local_kit_clone")"
    git clone -q "$kit_remote" "$local_kit_clone"
    git -C "$local_kit_clone" remote set-url origin \
        "https://github.com/someone-else/laravel-starter-kit-fork.git"
}

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

split_fetch_kit_result() {
    local last="${lines[$((${#lines[@]} - 1))]}"
    IFS=$'\t' read -r fk_dir fk_branch fk_sha <<< "$last"
}

# --- kit + target fixtures (classify / plan-manifest / apply) --------------
#
# A real kit repo with a bare origin (so `git show origin/main` resolves) plus a
# plain target dir. Stage kit files with kit_has, project files with project_has,
# then commit_kit before running a script.

given_classify_fixture() {
    classify_kit="$fixture/kit"
    target="$fixture/project"
    local remote="$fixture/kit-remote.git"

    git init -q --bare "$remote"
    git init -q "$classify_kit"
    git -C "$classify_kit" config user.name "Sync Skeleton Tests"
    git -C "$classify_kit" config user.email "sync-skeleton-tests@example.com"
    git -C "$classify_kit" checkout -q -b main
    git -C "$classify_kit" remote add origin "$remote"
    mkdir -p "$target"
}

kit_has() {
    local path="$1" content="$2"
    mkdir -p "$classify_kit/$(dirname "$path")"
    printf '%s' "$content" > "$classify_kit/$path"
    git -C "$classify_kit" add -- "$path"
}

project_has() {
    local path="$1" content="$2"
    mkdir -p "$target/$(dirname "$path")"
    printf '%s' "$content" > "$target/$path"
}

commit_kit() {
    git -C "$classify_kit" commit -qm "kit state"
    git -C "$classify_kit" push -q origin main
    git -C "$classify_kit" fetch -q origin
}

run_classify() {
    run bash "$classify" laravel-starter-kit "$classify_kit" main "$target"
}

# Asserts classify.sh emitted "<expected-status>\t<path>".
assert_classified() {
    local path="$1" expected="$2" got
    got="$(printf '%s\n' "$output" | awk -F'\t' -v p="$path" '$2 == p { print $1 }')"
    [ "$got" = "$expected" ] \
        || { echo "expected '$expected' for $path, got '${got:-<no line>}'" >&2; return 1; }
}

# Asserts classify.sh emitted no line at all for <path>.
assert_not_classified() {
    local path="$1"
    printf '%s\n' "$output" | awk -F'\t' -v p="$path" '$2 == p { exit 1 }' \
        || { echo "expected no line for '$path'" >&2; printf '%s\n' "$output" >&2; return 1; }
}

# --- plan-manifest fixtures ----------------------------------------------------

# A minimal pretty-printed manifest: a JSON object with one block named $1
# holding the remaining args as "name": "constraint" pairs.
#   manifest_json require-dev  phpstan/phpstan ^2.0  laravel/pint ^1.0
manifest_json() {
    local block="$1"; shift
    printf '{\n    "%s": {\n' "$block"
    local first=1
    while [ $# -ge 2 ]; do
        [ "$first" -eq 1 ] && first=0 || printf ',\n'
        printf '        "%s": "%s"' "$1" "$2"
        shift 2
    done
    printf '\n    }\n}\n'
}

# Writes composer.json + package.json into the kit tree. An omitted arg defaults
# to an empty require-dev / devDependencies block.
kit_manifest() {
    kit_has "composer.json" "${1:-$(manifest_json require-dev)}"
    kit_has "package.json" "${2:-$(manifest_json devDependencies)}"
}

project_manifest() {
    project_has "composer.json" "${1:-$(manifest_json require-dev)}"
    project_has "package.json" "${2:-$(manifest_json devDependencies)}"
}

run_plan_manifest() {
    run bash "$plan_manifest" laravel-starter-kit "$classify_kit" main "$target"
}

assert_directive() {
    local want
    printf -v want '%s\t%s\t%s\t%s' "$1" "$2" "$3" "$4"
    printf '%s\n' "$output" | grep -qxF "$want" \
        || { echo "missing directive: $1 $2 $3 $4" >&2; echo "got:" >&2; printf '%s\n' "$output" >&2; return 1; }
}

assert_no_directive_for() {
    local name="$1"
    printf '%s\n' "$output" | awk -F'\t' -v n="$name" '$3 == n { exit 1 }' \
        || { echo "unexpected directive for '$name'" >&2; printf '%s\n' "$output" >&2; return 1; }
}

# --- apply-new-files fixtures ------------------------------------------------

run_apply_new_files() {
    run bash "$apply_new_files" laravel-starter-kit "$classify_kit" main "$target"
}

# --- scan-imports fixtures ------------------------------------------------

run_scan_imports() {
    run bash "$scan_imports" "$@"
}

# --- run-tests / reconcile fixtures ----------------------------------------
#
# These scripts shell out to composer / npm / vendor binaries. Build $target as a
# plain (non-git) project dir and put fakes on PATH with given_fake_bin_on_path +
# write_fake_binary from test_helper.bash.

given_plain_project() {
    target="$fixture/project"
    mkdir -p "$target"
}

run_run_tests() {
    run env PATH="$fake_bin:$PATH" bash "$run_tests_sh" "$@"
}

run_reconcile() {
    run env PATH="$fake_bin:$PATH" bash "$reconcile" "$target"
}
