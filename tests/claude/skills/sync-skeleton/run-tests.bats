#!/usr/bin/env bats

load ../../../support/sync_skeleton_helper

setup() {
    new_sync_skeleton_fixture
    given_plain_project
    given_fake_bin_on_path
    given_composer_test_script
    baseline="$fixture/baseline"
}

teardown() {
    teardown_sync_skeleton_fixture
}

@test "records a passing php baseline from the discovered composer test" {
    # Arrange
    write_fake_binary composer "exit 0"

    # Act
    run_run_tests "$target" --baseline "$baseline"

    # Assert
    assert_success
    run cat "$baseline"
    assert_output_contains "php_tests"$'\t'"pass"$'\t'"composer test"
}

@test "php_tests prefers the low-level pest runner over the composer test alias" {
    # Arrange
    given_local_pest_binary

    # Act
    run_run_tests "$target" --baseline "$baseline"

    # Assert
    assert_success
    run cat "$baseline"
    assert_output_contains "php_tests"$'\t'"pass"$'\t'"vendor/bin/pest"
}

@test "run mode exits 1 when the test command fails" {
    # Arrange
    write_fake_binary composer "exit 1"

    # Act
    run_run_tests "$target"

    # Assert
    assert_status 1
    assert_output_contains "php_tests"$'\t'"fail"$'\t'"composer test"
}

@test "compare flags a php command that passed in the baseline and fails now" {
    # Arrange
    write_fake_binary composer "exit 0"
    run_run_tests "$target" --baseline "$baseline"
    write_fake_binary composer "exit 1"

    # Act
    run_run_tests "$target" --compare "$baseline"

    # Assert
    assert_status 1
    assert_output_contains "REGRESSION: php_tests"
}

@test "compare stays green when a pre-existing failure is still failing" {
    # Arrange
    write_fake_binary composer "exit 1"
    run_run_tests "$target" --baseline "$baseline"

    # Act
    run_run_tests "$target" --compare "$baseline"

    # Assert
    assert_success
}

@test "no discoverable command for any check is skip, not fail" {
    # Arrange
    given_no_php_project

    # Act
    run_run_tests "$target"

    # Assert
    assert_success
    assert_output_contains "php_tests"$'\t'"skip"
    assert_output_contains "js_build"$'\t'"skip"
}

@test "records the JS build under the detected package manager" {
    # Arrange
    given_no_php_project
    given_package_json_scripts build "vite build"
    given_js_lockfile pnpm-lock.yaml
    write_fake_binary pnpm "exit 0"

    # Act
    run_run_tests "$target" --baseline "$baseline"

    # Assert
    assert_success
    run cat "$baseline"
    assert_output_contains "js_build"$'\t'"pass"$'\t'"pnpm run build"
}

@test "compare flags the JS build regressing after the toolchain swap" {
    # Arrange
    given_no_php_project
    given_package_json_scripts build "vite build"
    given_js_lockfile package-lock.json
    write_fake_binary npm "exit 0"
    run_run_tests "$target" --baseline "$baseline"
    write_fake_binary npm "exit 1"

    # Act
    run_run_tests "$target" --compare "$baseline"

    # Assert
    assert_status 1
    assert_output_contains "REGRESSION: js_build"
}

@test "js typecheck prefers the types script over tsc" {
    # Arrange
    given_no_php_project
    given_package_json_scripts types "vue-tsc --noEmit" tsc "tsc"
    given_js_lockfile package-lock.json
    write_fake_binary npm "exit 0"

    # Act
    run_run_tests "$target"

    # Assert
    assert_success
    assert_output_contains "js_typecheck"$'\t'"pass"$'\t'"npm run types"
}
