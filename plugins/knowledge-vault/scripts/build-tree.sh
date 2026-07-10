#!/bin/bash
# Compatibility wrapper. New workflows invoke build_tree.py directly.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec python3 "$SCRIPT_DIR/build_tree.py" "$@"
