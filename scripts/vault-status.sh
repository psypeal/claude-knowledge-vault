#!/bin/bash
# knowledge-vault: Print vault status summary.
# Usage: bash vault-status.sh [vault-dir]

VAULT_DIR="${1:-.vault}"

if [ ! -d "$VAULT_DIR" ]; then
    echo "No vault found at $VAULT_DIR"
    exit 1
fi

MANIFEST="$VAULT_DIR/raw/.manifest.json"
STATE="$VAULT_DIR/wiki/.state.json"

echo "=== Knowledge Vault Status ==="
echo ""

# Source counts from manifest
if [ -f "$MANIFEST" ]; then
    python3 -c "
import json

with open('$MANIFEST', 'r') as f:
    m = json.load(f)

sources = m.get('sources', [])
total = len(sources)
compiled = sum(1 for s in sources if s.get('compiled'))
pending = total - compiled

print(f'Sources:    {total} total, {compiled} compiled, {pending} pending')

if pending > 0:
    print(f'  Pending:')
    for s in sources:
        if not s.get('compiled'):
            print(f'    - {s[\"slug\"]} ({s[\"type\"]})')
"
else
    echo "Sources:    no manifest found"
fi

echo ""

# Wiki stats from state
if [ -f "$STATE" ]; then
    python3 -c "
import json

with open('$STATE', 'r') as f:
    s = json.load(f)

stats = s.get('stats', {})
print(f'Concepts:   {stats.get(\"concept_count\", 0)}')
print(f'Summaries:  {stats.get(\"summary_count\", 0)}')
print(f'Outputs:    {stats.get(\"output_count\", 0)}')
print(f'')
print(f'Last compiled: {s.get(\"last_compiled\", \"never\")}')
print(f'Last lint:     {s.get(\"last_lint\", \"never\")}')
"
else
    echo "Wiki state: no state file found"
fi

echo ""

# Inbox count
CLIPPINGS_COUNT=$(find "$VAULT_DIR/Clippings" -name "*.md" 2>/dev/null | wc -l)
echo "Clippings:  $CLIPPINGS_COUNT items waiting"

echo ""
echo "==========================="
