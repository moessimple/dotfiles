call_branches() {
    zsh -c 'source "$1"; cd "$2"; branches "${@:3}"' \
        zsh "$dotfiles_dir/support/git/branches.sh" "$repository" "$@"
}

strip_ansi_colors() {
    sed -E $'s/\x1b\\[[0-9;]*m//g' <<< "$1"
}

assert_colorless_output_contains() {
    [[ "$(strip_ansi_colors "$output")" == *"$1"* ]] || false
}

assert_colorless_output_does_not_contain() {
    [[ "$(strip_ansi_colors "$output")" != *"$1"* ]] || false
}
