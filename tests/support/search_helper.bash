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

given_commit_adding_term_alongside_unrelated_file() {
    local term_path="$1" term="$2" unrelated_path="$3"
    printf '%s\n' "$term" > "$repository/$term_path"
    printf 'unrelated content\n' > "$repository/$unrelated_path"
    git -C "$repository" add "$term_path" "$unrelated_path"
    git -C "$repository" commit -qm "add $term_path and $unrelated_path"
}
