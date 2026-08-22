call_search() {
    zsh -c 'source "$1"; cd "$2"; search "${@:3}"' \
        zsh "$dotfiles_dir/support/git/search.sh" "$repository" "$@"
}

given_commit_adding_term() {
    local path="$1" term="$2"
    printf '%s\n' "$term" > "$repository/$path"
    git -C "$repository" add "$path"
    git -C "$repository" commit -qm "add $path"
}

given_commit_removing_term() {
    local path="$1"
    git -C "$repository" rm -q "$path"
    git -C "$repository" commit -qm "remove $path"
}

given_commit_unrelated_to_term() {
    local path="$1"
    printf 'unrelated content\n' > "$repository/$path"
    git -C "$repository" add "$path"
    git -C "$repository" commit -qm "add unrelated $path"
}
