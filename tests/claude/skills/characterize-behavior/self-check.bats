#!/usr/bin/env bats

load ../../../support/test_helper
load ../../../support/characterize_behavior_helper

setup() {
    new_dotfiles_fixture
    given_project_with_committed_acceptance_test
}

teardown() {
    teardown_dotfiles_fixture
}

@test "self-check accepts a clean working tree" {
    # Act
    run_self_check

    # Assert
    assert_success
    assert_output_contains "No hits."
}

@test "self-check rejects a repository without a commit to compare against" {
    # Arrange
    given_project_without_commits

    # Act
    run_self_check

    # Assert
    assert_failure
    assert_output_contains "needs a commit to compare against"
    assert_output_does_not_contain "No hits."
}

@test "self-check rejects a new acceptance test missing from the acceptance lock" {
    # Arrange
    write_project_file tests/Feature/InvoiceRulesTest.php "<?php\n\npest()->group('acceptance');\n\nit('RULE-002: numbers invoices per year', function () {\n    expect(1)->toBe(1);\n});\n"

    # Act
    run_self_check

    # Assert
    assert_failure
    assert_output_contains "## Acceptance tests missing from tests/acceptance.lock.json"
    assert_output_contains "tests/Feature/InvoiceRulesTest.php"
}

@test "self-check rejects changes to a committed acceptance test" {
    # Arrange
    write_project_file tests/Feature/OrderRulesTest.php "<?php\n\npest()->group('acceptance');\n\nit('RULE-001: deducts 5 % from an order of 500.00', function () {\n    expect(480.0)->toBe(480.0);\n});\n"

    # Act
    run_self_check

    # Assert
    assert_failure
    assert_output_contains "## Acceptance tests changed or deleted"
    assert_output_contains "tests/Feature/OrderRulesTest.php"
}

@test "self-check rejects deletion of a committed acceptance test" {
    # Arrange
    delete_project_file tests/Feature/OrderRulesTest.php

    # Act
    run_self_check

    # Assert
    assert_failure
    assert_output_contains "## Acceptance tests changed or deleted"
    assert_output_contains "tests/Feature/OrderRulesTest.php"
}

@test "self-check permits changes to characterization tests outside the acceptance group" {
    # Arrange
    write_project_file tests/Feature/OrderTest.php "<?php\n\nit('shows the order total', function () {\n    expect(475.0)->toBe(475.0);\n})->note('Notable: rounds down');\n"

    # Act
    run_self_check

    # Assert
    assert_success
    assert_output_does_not_contain "## Acceptance tests changed or deleted"
}

@test "self-check rejects changes to application code" {
    # Arrange
    write_project_file app/Order.php "<?php\n\nclass Order { public int \$total = 0; }\n"

    # Act
    run_self_check

    # Assert
    assert_failure
    assert_output_contains "## Changed files the skill must not touch"
    assert_output_contains "app/Order.php"
}

@test "self-check rejects changes to the acceptance guard test" {
    # Arrange
    write_project_file tests/Unit/AcceptanceGuardTest.php "<?php\n\nit('keeps every locked acceptance test unchanged', function () {\n    expect(true)->toBeTrue();\n})->skip();\n"

    # Act
    run_self_check

    # Assert
    assert_failure
    assert_output_contains "## Acceptance guard or lock entries changed"
    assert_output_contains "tests/Unit/AcceptanceGuardTest.php"
}

@test "self-check rejects a changed hash for an existing acceptance lock entry" {
    # Arrange
    write_project_file tests/acceptance.lock.json "{\n    \"tests/Feature/OrderRulesTest.php\": \"$invoice_rules_hash\"\n}\n"

    # Act
    run_self_check

    # Assert
    assert_failure
    assert_output_contains "## Acceptance guard or lock entries changed"
    assert_output_contains "tests/Feature/OrderRulesTest.php"
}

@test "self-check rejects deletion of an existing acceptance lock entry" {
    # Arrange
    write_project_file tests/acceptance.lock.json "{\n}\n"

    # Act
    run_self_check

    # Assert
    assert_failure
    assert_output_contains "## Acceptance guard or lock entries changed"
    assert_output_contains "tests/Feature/OrderRulesTest.php"
}

@test "self-check permits adding a new acceptance lock entry" {
    # Arrange
    write_project_file tests/Feature/InvoiceRulesTest.php "<?php\n\npest()->group('acceptance');\n\nit('RULE-002: numbers invoices per year', function () {\n    expect(1)->toBe(1);\n});\n"
    write_project_file tests/acceptance.lock.json "{\n    \"tests/Feature/OrderRulesTest.php\": \"$order_rules_hash\",\n    \"tests/Feature/InvoiceRulesTest.php\": \"$invoice_rules_hash\"\n}\n"

    # Act
    run_self_check

    # Assert
    assert_success
    assert_output_contains "No hits."
}

@test "self-check reports each removed entry when the acceptance lock is deleted" {
    # Arrange
    delete_project_file tests/acceptance.lock.json

    # Act
    run_self_check

    # Assert
    assert_failure
    assert_output_contains "## Acceptance guard or lock entries changed"
    assert_output_contains "tests/Feature/OrderRulesTest.php"
}

@test "self-check rejects deletion of the acceptance guard test" {
    # Arrange
    delete_project_file tests/Unit/AcceptanceGuardTest.php

    # Act
    run_self_check

    # Assert
    assert_failure
    assert_output_contains "## Acceptance guard or lock entries changed"
    assert_output_contains "tests/Unit/AcceptanceGuardTest.php"
}

@test "self-check permits adding the first acceptance lock to a project" {
    # Arrange
    given_acceptance_lock_not_committed
    write_project_file tests/acceptance.lock.json "{\n    \"tests/Feature/OrderRulesTest.php\": \"$order_rules_hash\"\n}\n"

    # Act
    run_self_check

    # Assert
    assert_success
    assert_output_contains "No hits."
}
