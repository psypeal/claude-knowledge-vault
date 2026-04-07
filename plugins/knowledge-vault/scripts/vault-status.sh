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
AGENT_FILE="$VAULT_DIR/agent.md"
SOURCES_FILE="$VAULT_DIR/sources.json"

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
lc = s.get('last_compiled') or 'never'
ll = s.get('last_lint') or 'never'
print(f'Last compiled: {lc}')
print(f'Last lint:     {ll}')
"
else
    echo "Wiki state: no state file found"
fi

echo ""

# Agent stats
if [ -f "$AGENT_FILE" ]; then
    python3 -c "
import re

with open('$AGENT_FILE', 'r') as f:
    content = f.read()

# Extract frontmatter values
tq = int(re.search(r'total_queries:\s*(\d+)', content).group(1)) if re.search(r'total_queries:\s*(\d+)', content) else 0
ch = int(re.search(r'cache_hits:\s*(\d+)', content).group(1)) if re.search(r'cache_hits:\s*(\d+)', content) else 0
tf = int(re.search(r'tier3_fallbacks:\s*(\d+)', content).group(1)) if re.search(r'tier3_fallbacks:\s*(\d+)', content) else 0

if tq == 0:
    print('Agent:      inactive (no queries yet)')
else:
    hit_rate = round(ch / tq * 100) if tq > 0 else 0
    print(f'Agent:      active ({tq} queries, {hit_rate}% cache hit rate)')

    def count_entries(section_name):
        pattern = rf'## {section_name}\n(.*?)(?=\n## |\Z)'
        match = re.search(pattern, content, re.DOTALL)
        if not match:
            return 0
        lines = [l for l in match.group(1).strip().split('\n') if l.startswith('- ')]
        return len(lines)

    clusters = count_entries('Concept Clusters')
    patterns = count_entries('Query Patterns')
    signals = count_entries('Source Signals')
    print(f'  Clusters: {clusters}/8')
    print(f'  Patterns: {patterns}/10')
    print(f'  Signals:  {signals}/15')
"
else
    echo "Agent:      not initialized"
fi

echo ""

# Research sources
if [ -f "$SOURCES_FILE" ]; then
    python3 -c "
import json

with open('$SOURCES_FILE', 'r') as f:
    s = json.load(f)

sources = s.get('configured_sources', [])
enabled = [x for x in sources if x.get('enabled')]
if enabled:
    names = ', '.join(x['name'] for x in enabled)
    print(f'Sources:    {len(enabled)} configured ({names})')
else:
    print('Sources:    none configured (run /knowledge-vault:setup-sources)')
"
else
    echo "Sources:    none configured"
fi

echo ""

# Clippings count
CLIPPINGS_COUNT=$(find "$VAULT_DIR/Clippings" -name "*.md" 2>/dev/null | wc -l)
echo "Clippings:  $CLIPPINGS_COUNT items waiting"

echo ""
echo "==========================="
