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

# --- classify fixtures -------------------------------------------------------
#
# classify.sh compares origin/<branch> of a kit clone against a target project.
# The fixture is a real kit repo with a bare origin (so `git show origin/main`
# resolves) plus a plain target directory. Stage kit files with kit_has /
# kit_has_binary, project files with project_has / project_has_binary, then call
# commit_kit before run_classify.

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

kit_has_binary() {
    local path="$1"
    mkdir -p "$classify_kit/$(dirname "$path")"
    printf '\x89PNG\r\n\x1a\x00\x00\x01kit' > "$classify_kit/$path"
    git -C "$classify_kit" add -- "$path"
}

project_has() {
    local path="$1" content="$2"
    mkdir -p "$target/$(dirname "$path")"
    printf '%s' "$content" > "$target/$path"
}

project_has_binary() {
    local path="$1"
    mkdir -p "$target/$(dirname "$path")"
    printf '\x89PNG\r\n\x1a\x00\x00\x02project' > "$target/$path"
}

commit_kit() {
    git -C "$classify_kit" commit -qm "kit state"
    git -C "$classify_kit" push -q origin main
    git -C "$classify_kit" fetch -q origin
}

run_classify() {
    run bash "$classify" laravel-starter-kit "$classify_kit" main "$target"
}

# Asserts classify.sh emitted <expected-status> in column 1 for <path>.
assert_classified() {
    local path="$1" expected="$2" got
    got="$(printf '%s\n' "$output" | awk -F'\t' -v p="$path" '$3 == p { print $1 }')"
    [ "$got" = "$expected" ] \
        || { echo "expected '$expected' for $path, got '${got:-<no line>}'" >&2; return 1; }
}

# Asserts classify.sh put <path> in bucket <expected> (column 2).
assert_bucket() {
    local path="$1" expected="$2" got
    got="$(printf '%s\n' "$output" | awk -F'\t' -v p="$path" '$3 == p { print $2 }')"
    [ "$got" = "$expected" ] \
        || { echo "expected bucket '$expected' for $path, got '${got:-<no line>}'" >&2; return 1; }
}

# --- kit path manifest ------------------------------------------------------
#
# Every path `git -C ~/Code/laravel-starter-kit ls-tree -r --name-only origin/main`
# reports, pinned at 30399efd8b58f6925f5cc0bdb01ab14d5d372d4d. buckets.bats
# checks that classify.sh assigns each of these a known bucket and that the
# cascade and reference/profiles/laravel-starter-kit.md stay in step. Regenerate
# this list whenever the kit adds or removes a tracked path.
SYNC_SKELETON_KIT_MANIFEST="
.ai/rules/actions.md
.ai/rules/index.md
.claude/skills/inertia-vue-development/SKILL.md
.claude/skills/infer-conventions/SKILL.md
.claude/skills/infer-conventions/references/checklist.md
.claude/skills/laravel-best-practices/SKILL.md
.claude/skills/laravel-best-practices/rules/advanced-queries.md
.claude/skills/laravel-best-practices/rules/architecture.md
.claude/skills/laravel-best-practices/rules/blade-views.md
.claude/skills/laravel-best-practices/rules/caching.md
.claude/skills/laravel-best-practices/rules/collections.md
.claude/skills/laravel-best-practices/rules/config.md
.claude/skills/laravel-best-practices/rules/db-performance.md
.claude/skills/laravel-best-practices/rules/eloquent.md
.claude/skills/laravel-best-practices/rules/error-handling.md
.claude/skills/laravel-best-practices/rules/events-notifications.md
.claude/skills/laravel-best-practices/rules/http-client.md
.claude/skills/laravel-best-practices/rules/mail.md
.claude/skills/laravel-best-practices/rules/migrations.md
.claude/skills/laravel-best-practices/rules/queue-jobs.md
.claude/skills/laravel-best-practices/rules/routing.md
.claude/skills/laravel-best-practices/rules/scheduling.md
.claude/skills/laravel-best-practices/rules/security.md
.claude/skills/laravel-best-practices/rules/style.md
.claude/skills/laravel-best-practices/rules/validation.md
.claude/skills/tailwindcss-development/SKILL.md
.claude/skills/testing-best-practices/SKILL.md
.claude/skills/testing-best-practices/rules/assertions.md
.claude/skills/testing-best-practices/rules/endpoint-tests.md
.claude/skills/testing-best-practices/rules/finding-features.md
.claude/skills/testing-best-practices/rules/isolation.md
.claude/skills/testing-best-practices/rules/naming.md
.claude/skills/testing-best-practices/rules/performance.md
.claude/skills/testing-best-practices/rules/review.md
.claude/skills/testing-best-practices/rules/security.md
.claude/skills/testing-best-practices/rules/test-data.md
.claude/skills/wayfinder-development/SKILL.md
.editorconfig
.env.example
.gitattributes
.github/actions/setup-app/action.yml
.github/dependabot.yml
.github/workflows/lint.yml
.github/workflows/static.yml
.github/workflows/tests.yml
.gitignore
.mcp.json
.npmrc
.nvmrc
CLAUDE.md
LICENSE
README.md
app/Http/Controllers/Controller.php
app/Http/Middleware/HandleInertiaRequests.php
app/Models/User.php
app/Providers/AppServiceProvider.php
artisan
boost.json
bootstrap/app.php
bootstrap/cache/.gitignore
bootstrap/providers.php
composer.json
composer.lock
config/app.php
config/auth.php
config/cache.php
config/database.php
config/essentials.php
config/filesystems.php
config/inertia.php
config/logging.php
config/mail.php
config/queue.php
config/services.php
config/session.php
database/.gitignore
database/factories/UserFactory.php
database/migrations/0001_01_01_000000_create_users_table.php
database/migrations/0001_01_01_000001_create_cache_table.php
database/migrations/0001_01_01_000002_create_jobs_table.php
database/seeders/DatabaseSeeder.php
package-lock.json
package.json
phpstan.neon
phpunit.xml
pint.json
pnpm-workspace.yaml
public/.htaccess
public/apple-touch-icon.png
public/favicon.ico
public/favicon.svg
public/index.php
public/robots.txt
rector.php
resources/css/app.css
resources/js/app.ts
resources/js/pages/Welcome.test.ts
resources/js/pages/Welcome.vue
resources/js/types/auth.ts
resources/js/types/global.d.ts
resources/js/types/index.ts
resources/js/types/vue-shims.d.ts
resources/views/app.blade.php
routes/console.php
routes/web.php
storage/app/.gitignore
storage/app/private/.gitignore
storage/app/public/.gitignore
storage/framework/.gitignore
storage/framework/cache/.gitignore
storage/framework/cache/data/.gitignore
storage/framework/sessions/.gitignore
storage/framework/testing/.gitignore
storage/framework/views/.gitignore
storage/logs/.gitignore
tests/Arch/FactoriesTest.php
tests/Arch/HttpTest.php
tests/Arch/ModelsTest.php
tests/Arch/ProvidersTest.php
tests/ArchTest.php
tests/Browser/Pest.php
tests/Browser/WelcomeTest.php
tests/Console/.gitkeep
tests/Http/WelcomeTest.php
tests/Pest.php
tests/TestCase.php
tests/Unit/Actions/.gitkeep
tests/Unit/Enums/.gitkeep
tests/Unit/Models/UserTest.php
tests/Unit/Support/.gitkeep
tsconfig.json
vite.config.ts
vitest.config.ts
vitest.setup.ts
"

# The canonical bucket vocabulary. classify.sh's cascade emits only these plus
# `unclassified` for a path that matches no arm; reference/profiles/laravel-starter-kit.md
# documents each. `unclassified` is deliberately not in this list, so
# assert_every_manifest_path_has_known_bucket fails the moment a pinned kit path
# stops matching the cascade.
SYNC_SKELETON_BUCKETS="quality-gate frontend-tooling essentials arch-tests frontend-test-setup agent-rules welcome-page misc-config drift-only not-in-scope never-touch"

# A kit repo (bare origin) whose origin/main tree is exactly the pinned manifest,
# every path an empty file. Lets buckets.bats drive the real classify.sh.
given_kit_manifest_as_fixture() {
    given_classify_fixture
    local path
    for path in $SYNC_SKELETON_KIT_MANIFEST; do
        mkdir -p "$classify_kit/$(dirname "$path")"
        : > "$classify_kit/$path"
    done
    git -C "$classify_kit" add -A
    commit_kit
}

# The pinned manifest is only meaningful against a real kit clone. Skip when
# $HOME/Code/laravel-starter-kit is absent, is a different repo, or has no
# fetched origin/main (e.g. CI, where the clone does not exist).
live_kit_clone_or_skip() {
    live_kit_clone="$HOME/Code/laravel-starter-kit"
    [ -d "$live_kit_clone/.git" ] || skip "no local kit clone at $live_kit_clone"
    local origin
    origin="$(git -C "$live_kit_clone" config --get remote.origin.url 2>/dev/null || true)"
    case "$origin" in
        *moessimple/laravel-starter-kit*) ;;
        *) skip "local clone origin is not the kit" ;;
    esac
    git -C "$live_kit_clone" rev-parse --verify --quiet origin/main >/dev/null \
        || skip "local clone has no origin/main"
}

# The kit tree at origin/main, one path per line, sorted.
live_kit_manifest() {
    git -C "$live_kit_clone" ls-tree -r --name-only origin/main | sort
}

# The pinned SYNC_SKELETON_KIT_MANIFEST, one path per line, sorted.
pinned_kit_manifest() {
    printf '%s\n' "$SYNC_SKELETON_KIT_MANIFEST" | sed '/^$/d' | sort
}

assert_known_bucket() {
    local bucket="$1" known
    for known in $SYNC_SKELETON_BUCKETS; do
        [ "$bucket" = "$known" ] && return 0
    done
    return 1
}

# Every pinned kit path must get a bucket from the canonical vocabulary.
assert_every_manifest_path_has_known_bucket() {
    local path bucket
    for path in $SYNC_SKELETON_KIT_MANIFEST; do
        bucket="$(printf '%s\n' "$output" | awk -F'\t' -v p="$path" '$3 == p { print $2 }')"
        assert_known_bucket "$bucket" \
            || { echo "path '$path' -> bucket '${bucket:-<none>}'" >&2; return 1; }
    done
}

# Every canonical bucket name must be documented in the profile catalog.
assert_buckets_documented_in_profile() {
    local bucket
    for bucket in $SYNC_SKELETON_BUCKETS; do
        grep -q -- "$bucket" "$profile" \
            || { echo "profile doc does not mention bucket '$bucket'" >&2; return 1; }
    done
}

# Every canonical bucket name must actually be used by the cascade (no stale
# entries in the vocabulary).
assert_every_bucket_used_by_cascade() {
    local bucket used
    used="$(printf '%s\n' "$output" | awk -F'\t' '{ print $2 }' | sort -u)"
    for bucket in $SYNC_SKELETON_BUCKETS; do
        printf '%s\n' "$used" | grep -qx -- "$bucket" \
            || { echo "bucket '$bucket' is in the vocabulary but never assigned" >&2; return 1; }
    done
}

# Runs preflight.sh capturing only its stderr, so a test can assert what the
# script routes there (the SPEC requires `git status --short` on stderr).
run_preflight_stderr() {
    run bash -c 'bash "$1" laravel-starter-kit "$2" 2>&1 1>/dev/null' _ "$preflight" "$target"
}
