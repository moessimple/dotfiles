#!/bin/bash
#
# Exit codes the quality-gate.sh dispatcher returns. Sourced by the dispatcher
# and by every caller that branches on one, so each number's meaning lives in
# one place.

EXIT_NOTHING_TO_CHECK=3 # no Composer project or no supported tooling; a pass, not a failure
EXIT_USAGE=64           # bad mode argument or unusable path argument
EXIT_INTERNAL=66        # could not enter the resolved project directory
