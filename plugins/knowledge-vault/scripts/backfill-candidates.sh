#!/bin/sh
# Backward-compatible wrapper. New workflows invoke backfill_candidates.py directly.
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec python3 "$SCRIPT_DIR/backfill_candidates.py" "$@"
