#!/bin/bash
# knowledge-vault: Append a pending entry to wiki/index.md without full rebuild.
# Saves ~950 tokens per ingest (avoids Claude reading index.md).
# Usage: bash index-append.sh <slug> <type> [vault-dir]

set -euo pipefail

SLUG="${1:?Usage: index-append.sh <slug> <type> [vault-dir]}"
TYPE="${2:?Missing type}"
VAULT_DIR="${3:-.vault}"
INDEX="$VAULT_DIR/wiki/index.md"

if [ ! -f "$INDEX" ]; then
    echo "Error: $INDEX not found"
    exit 1
fi

python3 - "$INDEX" "$SLUG" "$TYPE" << 'PYEOF'
import re
import sys

index_path, slug, type_ = sys.argv[1:4]

with open(index_path, 'r') as f:
    content = f.read()

# Update pending count in header
content = re.sub(
    r'## Pending Compilation \((\d+)\)',
    lambda m: f'## Pending Compilation ({int(m.group(1)) + 1})',
    content
)

# Remove 'no sources pending' placeholder
content = content.replace('_No sources pending._', '')

# Find the pending section and append entry
pending_pattern = r'(## Pending Compilation \(\d+\)\n)'
match = re.search(pending_pattern, content)
if match:
    insert_pos = match.end()
    # Skip any existing entries
    remaining = content[insert_pos:]
    lines = remaining.split('\n')
    i = 0
    while i < len(lines) and (lines[i].startswith('- ') or lines[i].strip() == ''):
        i += 1
    insert_pos += sum(len(l) + 1 for l in lines[:i])
    entry = f'- `{slug}` ({type_})\n'
    content = content[:insert_pos] + entry + content[insert_pos:]

# Normalize whitespace left behind by placeholder removal / insertion
content = re.sub(r'\n{3,}', '\n\n', content)
content = re.sub(r'(- `[^`]+` \([^)]+\)\n)(## )', r'\1\n\2', content)

with open(index_path, 'w') as f:
    f.write(content)

print(f'Added {slug} to pending')
PYEOF
