#!/bin/sh
# Backward-compatible wrapper. New workflows invoke enrich_references.py directly.
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec python3 "$SCRIPT_DIR/enrich_references.py" "$@"
