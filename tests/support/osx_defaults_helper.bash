# Runs osx-defaults.sh with a PATH that holds only `dirname`, which it needs to find
# output.sh, so a regression past the confirmation prompt fails on the first missing
# command (osascript, sudo) instead of changing this machine's settings.
given_path_without_system_commands() {
    restricted_path="$BATS_TEST_TMPDIR/restricted-bin"
    mkdir -p "$restricted_path"
    ln -s /usr/bin/dirname "$restricted_path/dirname"
}

# Sources <script> under set -e, as bin/install.sh and bin/reconfigure.sh do, answering
# its confirmation prompt with <answer>, then prints a line only a still-running caller reaches.
source_from_setup_script_answering() {
    local answer="$1" script="$2"
    PATH="$restricted_path" /bin/bash -c '
        set -e
        source "$1"
        echo "Setup script continued"
    ' bash "$script" <<< "$answer"
}

run_standalone_answering() {
    local answer="$1" script="$2"
    PATH="$restricted_path" /bin/bash "$script" <<< "$answer"
}
