given_fzf_selects() {
    local selection="$1"
    bin_dir="$fixture/bin"
    fzf_stdin_log="$fixture/fzf-stdin"
    mkdir -p "$bin_dir"
    cat > "$bin_dir/fzf" <<EOF
#!/bin/sh
cat > "$fzf_stdin_log"
printf '%s\n' "$selection"
EOF
    chmod +x "$bin_dir/fzf"
    export PATH="$bin_dir:$PATH"
}

given_fzf_selects_nothing() {
    bin_dir="$fixture/bin"
    fzf_stdin_log="$fixture/fzf-stdin"
    mkdir -p "$bin_dir"
    cat > "$bin_dir/fzf" <<EOF
#!/bin/sh
cat > "$fzf_stdin_log"
exit 1
EOF
    chmod +x "$bin_dir/fzf"
    export PATH="$bin_dir:$PATH"
}

assert_fzf_offered_candidate() {
    grep -qxF "$1" "$fzf_stdin_log"
}

assert_fzf_did_not_offer_candidate() {
    ! grep -qxF "$1" "$fzf_stdin_log" || false
}
