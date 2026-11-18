#!/bin/bash

# Output helpers for the entry points in bin/.
# The other setup scripts do not source this file: their tests stub these helpers first.
# The entry points source this file and machine-profile.sh relative to their own path, not
# through ~/.dotfiles like every other setup script: update.sh reports a missing or unusable
# ~/.dotfiles checkout with these helpers, so they cannot come from that checkout.

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

step() { echo ""; echo -e "${BLUE}➜${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1" >&2; exit 1; }
