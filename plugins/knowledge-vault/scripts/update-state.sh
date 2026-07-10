#!/bin/bash
# Compatibility wrapper. New workflows invoke kv.py directly.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec python3 "$SCRIPT_DIR/kv.py" update-state "$@"
