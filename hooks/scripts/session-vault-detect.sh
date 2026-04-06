#!/bin/bash
# Detect vault in current project and inject context.
VAULT_DIR=".vault"

if [ ! -d "$VAULT_DIR" ]; then
    exit 0
fi

MANIFEST="$VAULT_DIR/raw/.manifest.json"
PENDING=0
TOTAL=0
if [ -f "$MANIFEST" ]; then
    STATS=$(python3 -c "
import json
with open('$MANIFEST') as f:
    m = json.load(f)
s = m.get('sources', [])
print(f'{len(s)} {sum(1 for x in s if not x.get(\"compiled\"))}')" 2>/dev/null)
    TOTAL=$(echo "$STATS" | cut -d' ' -f1)
    PENDING=$(echo "$STATS" | cut -d' ' -f2)
fi

CLIPPINGS=$(find "$VAULT_DIR/Clippings" -name "*.md" 2>/dev/null | wc -l)

MSG="Knowledge vault active: $TOTAL sources"
[ "$PENDING" -gt 0 ] && MSG="$MSG ($PENDING pending compilation)"
[ "$CLIPPINGS" -gt 0 ] && MSG="$MSG, $CLIPPINGS clippings waiting"
MSG="$MSG. Use /vault:* commands."

echo "$MSG"
exit 0
