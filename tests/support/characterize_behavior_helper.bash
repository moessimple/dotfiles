# A project repository with one committed file of acceptance tests (Pest group "acceptance"), the
# acceptance guard test with a lock file listing that file, one committed characterization test, and
# one application file, without composer.lock, so self-check.sh needs no PHP.
order_rules_hash=1111111111111111111111111111111111111111111111111111111111111111
invoice_rules_hash=2222222222222222222222222222222222222222222222222222222222222222

given_project_with_committed_acceptance_test() {
    project="$fixture/project"
    mkdir -p "$project/tests/Feature" "$project/app"
    git init -q -b main "$project"
    configure_test_repository "$project"
    printf '<?php\n\nclass Order {}\n' >"$project/app/Order.php"
    printf "<?php\n\npest()->group('acceptance');\n\nit('RULE-001: deducts 5 %% from an order of 500.00', function () {\n    expect(475.0)->toBe(475.0);\n});\n" \
        >"$project/tests/Feature/OrderRulesTest.php"
    printf "<?php\n\nit('shows the order total', function () {\n    expect(475.0)->toBe(475.0);\n});\n" \
        >"$project/tests/Feature/OrderTest.php"
    mkdir -p "$project/tests/Unit"
    printf "<?php\n\nit('keeps every locked acceptance test unchanged', function () {\n    expect(true)->toBeTrue();\n});\n" \
        >"$project/tests/Unit/AcceptanceGuardTest.php"
    printf '{\n    "tests/Feature/OrderRulesTest.php": "%s"\n}\n' "$order_rules_hash" \
        >"$project/tests/acceptance.lock.json"
    git -C "$project" add .
    git -C "$project" commit -qm initial
}

given_project_without_commits() {
    project="$fixture/uncommitted-project"
    mkdir -p "$project/tests"
    git init -q -b main "$project"
}

write_project_file() {
    local path="$1" content="$2"
    mkdir -p "$(dirname "$project/$path")"
    printf '%b' "$content" >"$project/$path"
}

delete_project_file() {
    /bin/rm -- "$project/$1"
}

run_self_check() {
    run bash -c 'cd "$1" && "$2"' bash "$project" \
        "$dotfiles_dir/home/.claude/skills/characterize-behavior/scripts/self-check.sh"
}

# The state of a project set up before the acceptance guard existed: no lock file in HEAD.
given_acceptance_lock_not_committed() {
    git -C "$project" rm -q tests/acceptance.lock.json
    git -C "$project" commit -qm "remove acceptance lock"
}
