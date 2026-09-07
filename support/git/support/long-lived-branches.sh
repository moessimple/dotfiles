#!/usr/bin/env zsh

# The long-lived branches: sync refreshes them from upstream, prune never
# deletes them. One definition; callers turn it into an array or a regex
# alternation as they need.
long_lived_branches=(develop main master release)
