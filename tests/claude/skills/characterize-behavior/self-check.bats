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

@test "a clean working tree has no hits" {
    # Act
    run_self_check

    # Assert
    assert_success
    assert_output_contains "No hits."
}

@test "a new acceptance test is not a hit" {
    # Arrange
    write_project_file tests/Feature/InvoiceRulesTest.php "<?php\n\npest()->group('acceptance');\n\nit('RULE-002: numbers invoices per year', function () {\n    expect(1)->toBe(1);\n});\n"

    # Act
    run_self_check

    # Assert
    assert_success
    assert_output_contains "No hits."
}

@test "a changed committed acceptance test is a hit" {
    # Arrange
    write_project_file tests/Feature/OrderRulesTest.php "<?php\n\npest()->group('acceptance');\n\nit('RULE-001: deducts 5 % from an order of 500.00', function () {\n    expect(480.0)->toBe(480.0);\n});\n"

    # Act
    run_self_check

    # Assert
    assert_failure
    assert_output_contains "## Acceptance tests changed or deleted"
    assert_output_contains "tests/Feature/OrderRulesTest.php"
}

@test "a deleted committed acceptance test is a hit" {
    # Arrange
    delete_project_file tests/Feature/OrderRulesTest.php

    # Act
    run_self_check

    # Assert
    assert_failure
    assert_output_contains "## Acceptance tests changed or deleted"
    assert_output_contains "tests/Feature/OrderRulesTest.php"
}

@test "a changed characterization test is not an acceptance test hit" {
    # Arrange
    write_project_file tests/Feature/OrderTest.php "<?php\n\nit('shows the order total', function () {\n    expect(475.0)->toBe(475.0);\n})->note('Notable: rounds down');\n"

    # Act
    run_self_check

    # Assert
    assert_success
    assert_output_does_not_contain "## Acceptance tests changed or deleted"
}

@test "a changed application file is a hit" {
    # Arrange
    write_project_file app/Order.php "<?php\n\nclass Order { public int \$total = 0; }\n"

    # Act
    run_self_check

    # Assert
    assert_failure
    assert_output_contains "## Changed files the skill must not touch"
    assert_output_contains "app/Order.php"
}
