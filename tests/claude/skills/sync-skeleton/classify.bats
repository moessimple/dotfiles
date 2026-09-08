#!/usr/bin/env bats

load ../../../support/sync_skeleton_helper

setup() {
    new_sync_skeleton_fixture
}

teardown() {
    teardown_sync_skeleton_fixture
}

@test "a kit file the project lacks is new" {
    # Arrange
    given_classify_fixture
    kit_has "config/essentials.php" "<?php return [];"
    commit_kit

    # Act
    run_classify

    # Assert
    assert_success
    assert_classified "config/essentials.php" "new"
}

@test "a byte-identical file is identical" {
    # Arrange
    given_classify_fixture
    kit_has "pint.json" '{"preset":"laravel"}'
    project_has "pint.json" '{"preset":"laravel"}'
    commit_kit

    # Act
    run_classify

    # Assert
    assert_success
    assert_classified "pint.json" "identical"
}

@test "a text file with different bytes differs" {
    # Arrange
    given_classify_fixture
    kit_has "phpstan.neon" "parameters:\n    level: max\n"
    project_has "phpstan.neon" "parameters:\n    level: 5\n"
    commit_kit

    # Act
    run_classify

    # Assert
    assert_success
    assert_classified "phpstan.neon" "differs"
}

@test "a binary file with different bytes differs as binary" {
    # Arrange
    given_classify_fixture
    kit_has_binary "public/favicon.ico"
    project_has_binary "public/favicon.ico"
    commit_kit

    # Act
    run_classify

    # Assert
    assert_success
    assert_classified "public/favicon.ico" "differs-binary"
}

@test "a file the kit dropped but the project keeps is deleted-upstream" {
    # Arrange
    given_classify_fixture
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

@test "a manifest is always manifest even when byte-identical" {
    # Arrange
    given_classify_fixture
    kit_has "composer.json" '{"name":"kit"}'
    project_has "composer.json" '{"name":"kit"}'
    kit_has "package-lock.json" '{"lockfileVersion":3}'
    project_has "package-lock.json" '{"lockfileVersion":2}'
    commit_kit

    # Act
    run_classify

    # Assert
    assert_success
    assert_classified "composer.json" "manifest"
    assert_classified "package-lock.json" "manifest"
}

@test "a text=auto file that is byte-equal is identical, not differs" {
    # Arrange
    given_classify_fixture
    kit_has ".gitattributes" "* text=auto eol=lf\n"
    project_has ".gitattributes" "* text=auto eol=lf\n"
    commit_kit

    # Act
    run_classify

    # Assert
    assert_success
    assert_classified ".gitattributes" "identical"
}
