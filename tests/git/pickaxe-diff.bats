#!/usr/bin/env bats

load ../support/test_helper
load ../support/pickaxe_diff_helper

setup() {
    new_dotfiles_fixture
}

teardown() {
    teardown_dotfiles_fixture
}

@test "a hunk containing the search term is shown" {
    # Arrange
    given_clean_repository_on_main
    printf 'original\nNEEDLE_TERM\n' > "$repository/tracked.txt"

    # Act
    run call_pickaxe_diff NEEDLE_TERM -- tracked.txt

    # Assert
    assert_success
    assert_colorless_output_contains "+NEEDLE_TERM"
}

@test "a hunk without the search term is filtered out but the file header still appears" {
    # Arrange
    given_clean_repository_on_main
    printf 'original\nUNRELATED_CHANGE\n' > "$repository/tracked.txt"

    # Act
    run call_pickaxe_diff NEEDLE_TERM -- tracked.txt

    # Assert
    assert_success
    assert_colorless_output_contains "diff --git a/tracked.txt b/tracked.txt"
    assert_colorless_output_does_not_contain "UNRELATED_CHANGE"
}

@test "a newly added file's hunk is shown with a new file mode header" {
    # Arrange
    given_clean_repository_on_main
    printf 'NEEDLE_TERM\n' > "$repository/new.txt"
    git -C "$repository" add new.txt

    # Act
    run call_pickaxe_diff NEEDLE_TERM --cached -- new.txt

    # Assert
    assert_success
    assert_colorless_output_contains "new file mode"
    assert_colorless_output_contains "+NEEDLE_TERM"
}

@test "a deleted file's hunk is shown with a deleted file mode header" {
    # Arrange
    given_clean_repository_on_main
    printf 'NEEDLE_TERM\n' > "$repository/old.txt"
    git -C "$repository" add old.txt
    git -C "$repository" commit -qm "add old.txt"
    rm "$repository/old.txt"

    # Act
    run call_pickaxe_diff NEEDLE_TERM -- old.txt

    # Assert
    assert_success
    assert_colorless_output_contains "deleted file mode"
    assert_colorless_output_contains "-NEEDLE_TERM"
}

@test "a file mode change without a content change reports the old and new mode" {
    # Arrange
    given_clean_repository_on_main
    printf 'NEEDLE_TERM\n' > "$repository/exe.txt"
    git -C "$repository" add exe.txt
    git -C "$repository" commit -qm "add exe.txt"
    chmod +x "$repository/exe.txt"

    # Act
    run call_pickaxe_diff NEEDLE_TERM -- exe.txt

    # Assert
    assert_success
    assert_colorless_output_contains "old mode 100644"
    assert_colorless_output_contains "new mode 100755"
}

@test "a search term starting with a dash is matched literally instead of being parsed as an option" {
    # Arrange
    given_clean_repository_on_main
    printf 'original\n-NEEDLE\n' > "$repository/tracked.txt"

    # Act
    run call_pickaxe_diff "-NEEDLE" -- tracked.txt

    # Assert
    assert_success
    assert_colorless_output_contains "+-NEEDLE"
}

@test "hunk matching is case-insensitive" {
    # Arrange
    given_clean_repository_on_main
    printf 'original\nUNIQUE_TERM\n' > "$repository/tracked.txt"

    # Act
    run call_pickaxe_diff unique_term -- tracked.txt

    # Assert
    assert_success
    assert_colorless_output_contains "+UNIQUE_TERM"
}
