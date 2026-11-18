#!/usr/bin/env zsh

# List local branches by recent commit, including upstream information
function branches() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: branches"
        echo "  Lists local branches sorted by most recent commit, with upstream tracking info."
        return 0
    fi

    git for-each-ref \
        --sort=-committerdate \
        --format='%(color:green)%(align:24)%(committerdate:relative)%(end)%(color:reset)  %(if)%(HEAD)%(then)%(color:bold yellow)* %(else)%(color:yellow)  %(end)%(refname:short)%(color:reset)%(if)%(upstream)%(then)  %(color:red)→ %(upstream:short)%(color:reset)%(end)' \
        refs/heads
}
