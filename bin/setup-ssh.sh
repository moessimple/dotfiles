#!/bin/bash

set -eu

if [ "$#" -ne 1 ] || [ -z "${1//[[:space:]]/}" ]; then
    echo 'Usage: setup-ssh.sh <your-github-email>' >&2
    exit 1
fi

key="$HOME/.ssh/id_ed25519"
for path in "$key" "$key.pub"; do
    if [ -e "$path" ] || [ -L "$path" ]; then
        echo "$path already exists. Keep your existing key or move it before running this script." >&2
        exit 1
    fi
done

umask 077
mkdir -p "$HOME/.ssh"
ssh-keygen -t ed25519 -C "$1" -f "$key"

if [ -z "${SSH_AUTH_SOCK:-}" ]; then
    agent=$(ssh-agent -s)
    eval "$agent"
fi

ssh-add --apple-use-keychain "$key"
pbcopy < "$key.pub"
echo 'Public key copied. Add it at https://github.com/settings/keys'
