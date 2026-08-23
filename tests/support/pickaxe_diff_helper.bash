# Invokes pickaxe-diff.sh the same way search() does: as Git's configured
# external diff driver, so the test exercises the real invocation protocol
# (path, old-file, old-hex, old-mode, new-file, new-hex, new-mode) instead of
# calling the script's internals directly.
call_pickaxe_diff() {
    local term="$1"
    shift
    GREPDIFF_REGEX="$term" git -C "$repository" \
        -c diff.external="$dotfiles_dir/support/git/pickaxe-diff.sh" \
        diff --ext-diff "$@"
}
