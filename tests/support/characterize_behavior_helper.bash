# A project repository with one committed acceptance test and one application file, without
# composer.lock, so self-check.sh needs no PHP.
given_project_with_committed_acceptance_test() {
    project="$fixture/project"
    mkdir -p "$project/tests/Acceptance" "$project/app"
    git init -q -b main "$project"
    configure_test_repository "$project"
    printf '<?php\n\nclass Order {}\n' > "$project/app/Order.php"
    printf "<?php\n\nit('RULE-001: deducts 5 %% from an order of 500.00', function () {\n    expect(475.0)->toBe(475.0);\n});\n" \
        > "$project/tests/Acceptance/OrderTest.php"
    git -C "$project" add .
    git -C "$project" commit -qm initial
}

write_project_file() {
    local path="$1" content="$2"
    mkdir -p "$(dirname "$project/$path")"
    printf '%b' "$content" > "$project/$path"
}

delete_project_file() {
    /bin/rm -- "$project/$1"
}

run_self_check() {
    run bash -c 'cd "$1" && "$2"' bash "$project" \
        "$dotfiles_dir/home/.claude/skills/characterize-behavior/scripts/self-check.sh"
}
