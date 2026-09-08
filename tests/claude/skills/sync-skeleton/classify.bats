#!/usr/bin/env bats

load ../../../support/sync_skeleton_helper

setup() {
    new_sync_skeleton_fixture
    given_classify_fixture
}

teardown() {
    teardown_sync_skeleton_fixture
}

@test "a gate file the project lacks is new" {
    # Arrange
    kit_has "config/essentials.php" "<?php return [];"
    commit_kit

    # Act
    run_classify

    # Assert
    assert_success
    assert_classified "config/essentials.php" "new"
}

@test "a byte-identical gate file is already-present" {
    # Arrange
    kit_has "pint.json" '{"preset":"laravel"}'
    project_has "pint.json" '{"preset":"laravel"}'
    commit_kit

    # Act
    run_classify

    # Assert
    assert_success
    assert_classified "pint.json" "already-present"
}

@test "a gate file with different bytes differs" {
    # Arrange
    kit_has "phpstan.neon" "parameters:\n    level: max\n"
    project_has "phpstan.neon" "parameters:\n    level: 5\n"
    commit_kit

    # Act
    run_classify

    # Assert
    assert_success
    assert_classified "phpstan.neon" "differs"
}

@test "an eslint config the kit dropped but the project keeps is deleted-upstream" {
    # Arrange
    kit_has "vite.config.ts" "export default {}"
    project_has "vite.config.ts" "export default {}"
    project_has "eslint.config.js" "export default []"
    commit_kit

    # Act
    run_classify

    # Assert
    assert_success
    assert_classified "eslint.config.js" "deleted-upstream"
}

@test "a kit path under a gate glob that gate-paths.txt omits is ungrouped" {
    # Arrange
    kit_has ".github/workflows/coverage.yml" "name: coverage"
    commit_kit

    # Act
    run_classify

    # Assert
    assert_success
    assert_classified ".github/workflows/coverage.yml" "ungrouped"
}

@test "manifests are not classified here" {
    # Arrange
    kit_has "composer.json" '{"name":"kit"}'
    project_has "composer.json" '{"name":"project"}'
    commit_kit

    # Act
    run_classify

    # Assert
    assert_success
    assert_not_classified "composer.json"
}
