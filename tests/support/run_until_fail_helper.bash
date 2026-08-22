call_puf()   { call_dotfiles_function puf "$@"; }
call_puff()  { call_dotfiles_function puff "$@"; }
call_ppuf()  { call_dotfiles_function ppuf "$@"; }
call_ppuff() { call_dotfiles_function ppuff "$@"; }

# Fake php that succeeds on every run until the given run number, then fails,
# so the retry loop in _run_until_fail has something real to observe and stop on.
given_php_fails_on_run() {
    local fail_at="$1"
    write_fake_binary php "count_file=\"$fixture/php-run-count\"
count=\$(( \$(cat \"\$count_file\" 2>/dev/null || echo 0) + 1 ))
echo \"\$count\" > \"\$count_file\"
[ \"\$count\" -lt $fail_at ]"
}
