#!/usr/bin/env bash
#
# Exit codes the quality-gate.sh dispatcher returns. Sourced by the dispatcher
# and by every caller that branches on one, so each number's meaning lives in
# one place.

exit_nothing_to_check=3   # no Composer project or no supported tooling; a pass, not a failure
exit_usage=64             # bad mode argument or unusable path argument
exit_unsafe_path=65       # path escapes the project or points inside .git
exit_internal=66          # could not enter the resolved project directory
