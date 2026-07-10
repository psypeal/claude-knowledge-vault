#!/bin/bash
# Print a concise vault status summary.

set -euo pipefail

VAULT_DIR="${1:-.vault}"

if [ ! -d "$VAULT_DIR" ]; then
    echo "No vault found at $VAULT_DIR"
    exit 1
fi

MANIFEST="$VAULT_DIR/raw/.manifest.json"
STATE="$VAULT_DIR/wiki/.state.json"
AGENT_FILE="$VAULT_DIR/agent.md"
SOURCES_FILE="$VAULT_DIR/sources.json"

echo "=== Knowledge Vault Status ==="
echo

if [ -f "$MANIFEST" ]; then
    python3 - "$MANIFEST" <<'PYEOF'
import json
import sys

try:
    with open(sys.argv[1], encoding='utf-8') as handle:
        manifest = json.load(handle)
except (json.JSONDecodeError, OSError) as error:
    print(f'Sources:    manifest unreadable ({error.__class__.__name__})')
    raise SystemExit

sources = manifest.get('sources', [])
compiled = sum(1 for source in sources if source.get('compiled'))
pending = [source for source in sources if not source.get('compiled')]
print(f'Sources:    {len(sources)} total, {compiled} compiled, {len(pending)} pending')
if pending:
    print('  Pending:')
    for source in pending:
        print(f'    - {source.get("slug", "?")} ({source.get("type", "?")})')
PYEOF
else
    echo "Sources:    no manifest found"
fi

echo

if [ -f "$STATE" ]; then
    python3 - "$STATE" <<'PYEOF'
import json
import sys

try:
    with open(sys.argv[1], encoding='utf-8') as handle:
        state = json.load(handle)
except (json.JSONDecodeError, OSError):
    print('Wiki state: unreadable')
    raise SystemExit

stats = state.get('stats', {})
print(f'Concepts:   {stats.get("concept_count", 0)}')
print(f'Summaries:  {stats.get("summary_count", 0)}')
print(f'Outputs:    {stats.get("output_count", 0)}')
print(f'Last compiled: {state.get("last_compiled") or "never"}')
print(f'Last lint:     {state.get("last_lint") or "never"}')
PYEOF
else
    echo "Wiki state: no state file found"
fi

echo

if [ -f "$AGENT_FILE" ]; then
    python3 - "$AGENT_FILE" <<'PYEOF'
import re
import sys

try:
    content = open(sys.argv[1], encoding='utf-8').read()
except OSError:
    print('Agent:      unreadable')
    raise SystemExit

def number(name):
    match = re.search(rf'{name}:\s*(\d+)', content)
    return int(match.group(1)) if match else 0

queries = number('total_queries')
hits = number('cache_hits')
if queries == 0:
    print('Agent:      inactive (no queries yet)')
else:
    print(f'Agent:      active ({queries} queries, {round(hits / queries * 100)}% cache hit rate)')
PYEOF
else
    echo "Agent:      not initialized"
fi

echo

if [ -f "$SOURCES_FILE" ]; then
    python3 - "$SOURCES_FILE" <<'PYEOF'
import json
import sys

try:
    with open(sys.argv[1], encoding='utf-8') as handle:
        config = json.load(handle)
except (json.JSONDecodeError, OSError):
    print('Research:   sources.json unreadable')
    raise SystemExit

enabled = [source for source in config.get('configured_sources', []) if source.get('enabled')]
if enabled:
    names = ', '.join(source.get('name', source.get('id', '?')) for source in enabled)
    print(f'Research:   {len(enabled)} configured ({names})')
else:
    print('Research:   none configured (run the setup-sources workflow)')
PYEOF
else
    echo "Research:   none configured"
fi

if [ -d "$VAULT_DIR/Clippings" ]; then
    CLIPPINGS_COUNT="$(find "$VAULT_DIR/Clippings" -type f -name '*.md' | wc -l)"
else
    CLIPPINGS_COUNT=0
fi

echo
echo "Clippings:  $CLIPPINGS_COUNT items waiting"
echo "==========================="
