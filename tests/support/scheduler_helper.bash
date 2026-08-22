call_scheduler() {
    call_dotfiles_function scheduler
}

# The scheduler loop has no exit condition of its own, so the fake sleep lets
# it run for two iterations (proving it really loops) and then terminates the
# zsh process running it, the same way a user would stop it with Ctrl-C.
given_sleep_stops_the_loop_after_two_iterations() {
    write_fake_binary sleep "count_file=\"$fixture/sleep-count\"
count=\$(( \$(cat \"\$count_file\" 2>/dev/null || echo 0) + 1 ))
echo \"\$count\" > \"\$count_file\"
if [ \"\$count\" -ge 2 ]; then
    kill -TERM \"\$PPID\"
    /bin/sleep 0.05
fi"
}
