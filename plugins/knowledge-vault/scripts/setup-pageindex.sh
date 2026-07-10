#!/bin/bash
# Compatibility wrapper. New workflows invoke setup_pageindex.py directly.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec python3 "$SCRIPT_DIR/setup_pageindex.py"
