#!/bin/bash
# Compatibility wrapper. New workflows invoke detect_mcp_sources.py directly.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec python3 "$SCRIPT_DIR/detect_mcp_sources.py"
