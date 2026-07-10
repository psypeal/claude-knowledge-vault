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
    STATS=$(python3 - "$MANIFEST" << 'PYEOF' 2>/dev/null
import json, sys
with open(sys.argv[1]) as f:
    m = json.load(f)
s = m.get('sources', [])
print(f'{len(s)} {sum(1 for x in s if not x.get("compiled"))}')
PYEOF
)
    TOTAL=$(echo "$STATS" | cut -d' ' -f1)
    PENDING=$(echo "$STATS" | cut -d' ' -f2)
fi

case "$TOTAL" in ''|*[!0-9]*) TOTAL=0 ;; esac
case "$PENDING" in ''|*[!0-9]*) PENDING=0 ;; esac

CLIPPINGS=$(find "$VAULT_DIR/Clippings" -name "*.md" 2>/dev/null | wc -l)

MSG="Knowledge vault active: $TOTAL sources"
[ "$PENDING" -gt 0 ] && MSG="$MSG ($PENDING pending compilation)"
[ "$CLIPPINGS" -gt 0 ] && MSG="$MSG, $CLIPPINGS clippings waiting"
MSG="$MSG. Use the Knowledge Vault workflows when requested."

echo "$MSG"
exit 0
