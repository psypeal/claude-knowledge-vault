#!/bin/bash
# Compatibility wrapper. New workflows invoke kv.py directly.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SLUG="${1:?Usage: index-append.sh <slug> <type> [vault-dir]}"
TYPE="${2:?Missing type}"
VAULT_DIR="${3:-.vault}"
exec python3 "$SCRIPT_DIR/kv.py" index-add "$SLUG" "$TYPE" --vault "$VAULT_DIR"
