#!/bin/bash
# knowledge-vault: Update key=value pairs in wiki/.state.json
# Usage: bash update-state.sh <vault-dir> <key=value> [key=value...]
# Example: bash update-state.sh .vault last_lint="2026-04-06T12:00:00Z"
#          bash update-state.sh .vault last_compiled="2026-04-06T12:00:00Z" pending_count=3

set -euo pipefail

VAULT_DIR="${1:-.vault}"
if [ $# -gt 0 ]; then
    shift
fi

STATE="$VAULT_DIR/wiki/.state.json"

if [ ! -f "$STATE" ]; then
    echo '{"version": 1}' > "$STATE"
fi

# Collect remaining args as key=value pairs
PAIRS=("$@")

if [ ${#PAIRS[@]} -eq 0 ]; then
    echo "Error: No key=value pairs provided."
    echo "Usage: bash update-state.sh <vault-dir> <key=value> [key=value...]"
    exit 1
fi

python3 - "$STATE" "${PAIRS[@]}" << 'PYEOF'
import json, sys

state_path = sys.argv[1]
pairs = sys.argv[2:]

with open(state_path, 'r') as f:
    state = json.load(f)

for pair in pairs:
    if '=' not in pair:
        print(f"Warning: skipping invalid pair '{pair}' (no '=' found)")
        continue
    key, _, value = pair.partition('=')
    # Try to parse as JSON (for numbers, booleans, null)
    try:
        value = json.loads(value)
    except (json.JSONDecodeError, ValueError):
        pass  # keep as string
    state[key] = value

with open(state_path, 'w') as f:
    json.dump(state, f, indent=2)

print(f"Updated {state_path}: {', '.join(pairs)}")
PYEOF
