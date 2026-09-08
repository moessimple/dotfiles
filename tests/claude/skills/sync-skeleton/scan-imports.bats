#!/usr/bin/env bats

load ../../../support/sync_skeleton_helper

setup() {
    new_sync_skeleton_fixture
    given_plain_project
    mkdir -p "$target/resources/js"
}

teardown() {
    teardown_sync_skeleton_fixture
}

@test "reports aliased and relative imports with file and line" {
    # Arrange
    cat > "$target/resources/js/vitest.setup.ts" <<'TS'
import '@testing-library/jest-dom'
import { render } from '@/test/helpers'
import fixtures from '../fixtures'
TS

    # Act
    run_scan_imports "$target/resources/js/vitest.setup.ts"

    # Assert
    assert_success
    assert_output_contains "vitest.setup.ts:2:"
    assert_output_contains "@/test/helpers"
    assert_output_contains "vitest.setup.ts:3:"
}

@test "package-only imports produce empty output and still succeed" {
    # Arrange
    cat > "$target/resources/js/app.ts" <<'TS'
import { createApp } from 'vue'
import { createInertiaApp } from '@inertiajs/vue3'
TS

    # Act
    run_scan_imports "$target/resources/js/app.ts"

    # Assert
    assert_success
    assert_output_equals ""
}
