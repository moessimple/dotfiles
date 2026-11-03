#!/bin/bash

# Python packages the scripts and examples of the pdf skill import. Its command-line tools
# (qpdf, poppler for pdf2image and pdftotext, tesseract for pytesseract) are in the Brewfile.
PYTHON_PACKAGES=(
    pandas
    pdf2image
    pdfplumber
    pypdf
    pypdfium2
    pytesseract
    reportlab
)

# The skills run plain `python3`, so the packages have to be importable from Homebrew's
# interpreter itself, not from a virtualenv. Homebrew marks that interpreter as externally
# managed (PEP 668), and pip refuses to install or uninstall without --break-system-packages,
# set through the environment because `pip list` rejects it as an option. --user keeps
# the packages in ~/Library/Python/<version>, apart from Homebrew's own site-packages. That
# directory is per Python minor version, so after Homebrew moves to a new one the packages
# are missing until the next install or update run installs them there again.
python_pip() {
    PIP_BREAK_SYSTEM_PACKAGES=1 python3 -m pip "$@" --disable-pip-version-check
}

step "Installing Python packages"
python_pip install --user --quiet --no-warn-script-location "${PYTHON_PACKAGES[@]}" || warn "Some Python packages failed to install"
success "Python packages processed"

# Removes any user-installed Python package that isn't in PYTHON_PACKAGES. Same idea as
# `brew bundle cleanup --force` and npm_packages_cleanup in npm-packages.sh.
python_packages_cleanup() {
    command -v python3 &>/dev/null || return 0

    step "Checking for undeclared Python packages"

    # --not-required lists only packages no other installed package depends on, so the
    # dependencies of declared packages are never candidates. shortcut: the dependencies of a
    # removed package become candidates only on the following run, which removes them then.
    # pipefail, and the assignment kept out of `local`, so a failing pip or a missing jq
    # surfaces instead of looking like an empty list and reporting a green run over a broken one.
    local installed
    if ! installed=$(set -o pipefail; python_pip list --user --not-required --format=json 2>/dev/null | jq -r '.[].name'); then
        warn "Could not read user-installed Python packages, skipping cleanup"
        return 0
    fi

    local name found_undeclared=0
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        # Case-insensitive, because pip reports a package under the capitalization its
        # metadata uses (e.g. Pillow), which need not match the declared name.
        if ! printf '%s\n' "${PYTHON_PACKAGES[@]}" | grep -qixF "$name"; then
            found_undeclared=1
            warn "Removing undeclared Python package: $name (not in python-packages.sh)"
            python_pip uninstall --yes --quiet "$name" || warn "Could not remove $name, remove it manually"
        fi
    done <<< "$installed"

    # An `if`, not `&&`, which would return 1 after a removal and trip `set -e` in bin/update.sh
    if [ "$found_undeclared" -eq 0 ]; then
        success "No undeclared Python packages found"
    fi
}
