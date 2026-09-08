# Fixtures for tests/setup/herd/xdebug-ini.bats.
#
# support/setup/herd-debug-ini.sh is a straight-line script (not a function) that
# bin/install.sh and bin/reconfigure.sh source. These helpers stand in for the two
# things it reaches outside the repo:
#   - `herd php:list --json`, faked on PATH to report chosen PHP versions
#   - the Herd.app resources tree (debug.ini template + xdebug-<slug>-arm64.so
#     builds), redirected with HERD_RESOURCES_DIR to a fixture directory
# HOME points at a fixture so the generated ini files land under a temp scan dir.

setup_herd_debug_ini_fixture() {
    target="$dotfiles_dir/support/setup/herd-debug-ini.sh"
    test_home="$fixture/home"
    herd_resources="$fixture/herd-resources"
    mkdir -p "$test_home" "$herd_resources"
    given_fake_bin_on_path
}

# Writes a fake `herd` that answers `php:list --json` with the given versions marked
# installed, plus one uninstalled version so the script's `select(.installed)` filter
# is always exercised.
given_herd_reports_installed_php_versions() {
    local entries='{"version":"7.4","installed":false}'
    local version
    for version in "$@"; do
        entries="$entries,{\"version\":\"$version\",\"installed\":true}"
    done

    cat > "$fake_bin/herd" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$fake_bin/herd.calls"
[ "\$*" = "php:list --json" ] && printf '%s\n' '[$entries]'
EOF
    chmod +x "$fake_bin/herd"
}

# Creates the Herd-shipped xdebug-<slug>-arm64.so for each given version slug.
given_herd_ships_xdebug_build_for() {
    mkdir -p "$herd_resources/xdebug"
    local slug
    for slug in "$@"; do
        printf 'fake xdebug build\n' > "$herd_resources/xdebug/xdebug-$slug-arm64.so"
    done
}

# Creates Herd's debug.ini template, matching the real file's XDEBUG_PATH placeholder.
given_herd_debug_template_is_present() {
    mkdir -p "$herd_resources/config/php"
    cat > "$herd_resources/config/php/debug.ini" <<'TEMPLATE'
zend_extension=XDEBUG_PATH
xdebug.mode=debug,develop
xdebug.start_with_request=yes
xdebug.start_upon_error=yes
TEMPLATE
}

given_existing_ini_file() {
    local relative_path="$1" contents="$2"
    local absolute_path="$test_home/Library/Application Support/Herd/config/php/$relative_path"
    mkdir -p "$(dirname "$absolute_path")"
    printf '%s\n' "$contents" > "$absolute_path"
}

# Sources herd-debug-ini.sh the way bin/reconfigure.sh does: step/warn/success/error
# defined by the caller, WARN:/ERROR: prefixes make those lines assertable. Call it
# through `run` from the test body.
run_herd_debug_ini_setup() {
    HOME="$test_home" HERD_RESOURCES_DIR="$herd_resources" bash -c '
        step() { :; }
        warn() { echo "WARN: $*"; }
        success() { echo "SUCCESS: $*"; }
        error() { echo "ERROR: $*"; exit 1; }
        source "$1"
    ' bash "$target"
}

ini_path() {
    printf '%s' "$test_home/Library/Application Support/Herd/config/php/$1"
}

assert_always_loaded_xdebug_ini() {
    local slug="$1"
    local ini
    ini="$(ini_path "$slug/xdebug.ini")"
    assert_file_exists "$ini"
    grep -qxF "zend_extension=$herd_resources/xdebug/xdebug-$slug-arm64.so" "$ini" || return 1
    grep -qxF "xdebug.mode=off" "$ini" || return 1
}

assert_herd_debug_ini() {
    local slug="$1"
    local ini
    ini="$(ini_path "$slug/debug/debug.ini")"
    assert_file_exists "$ini"
    grep -qxF "zend_extension=$herd_resources/xdebug/xdebug-$slug-arm64.so" "$ini" || return 1
    grep -qxF "xdebug.mode=debug,develop" "$ini" || return 1
}

assert_no_ini_files_for() {
    local slug="$1"
    assert_path_does_not_exist "$(ini_path "$slug/xdebug.ini")"
    assert_path_does_not_exist "$(ini_path "$slug/debug")"
}
