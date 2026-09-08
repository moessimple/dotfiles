#!/usr/bin/env bash
# scan-imports.sh - scan applied `new` files for module imports that may point at
# a helper the project does not have (Vue/TS: `@/`, `~/`, `./`, `../`).
#
# Usage: scan-imports.sh <file...>
#
# Output mirrors `grep -EHn`: `<file>:<line>:<match>` per import. Empty output
# means nothing to chase. Always exits 0 - finding nothing is not an error. For
# each hit the agent checks the target exists in the project; a missing one is a
# follow-up dependency, not a done group.

set -uo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: scan-imports.sh <file...>" >&2
    exit 64
fi

grep -EHn "from ['\"](@/|~/|\./|\.\./)" "$@" 2>/dev/null || true
