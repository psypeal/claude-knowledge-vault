#!/bin/bash
# knowledge-vault: Create a raw source file and update the manifest.
# Usage: bash ingest.sh <slug> <title> <type> [tags...]

set -euo pipefail

VAULT_DIR=".vault"

if [ ! -d "$VAULT_DIR" ]; then
    echo "Error: No .vault/ directory found. Run /knowledge-vault:init first."
    exit 1
fi

SLUG="${1:?Usage: ingest.sh <slug> <title> <type> [tags...]}"
TITLE="${2:?Missing title}"
TYPE="${3:?Missing type (paper|article|report|manual|filing|guideline|repo|dataset|meeting|notes|clip)}"
shift 3
TAGS=("$@")

RAW_FILE="$VAULT_DIR/raw/$SLUG.md"
MANIFEST="$VAULT_DIR/raw/.manifest.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [ -f "$RAW_FILE" ]; then
    echo "Error: $RAW_FILE already exists."
    exit 1
fi

# Create raw file and update manifest via Python (safe against special chars in title).
# The manifest is parsed FIRST so a missing/corrupt manifest fails before any file
# is written — no orphaned raw files.
python3 - "$SLUG" "$TITLE" "$TYPE" "$TIMESTAMP" "$RAW_FILE" "$MANIFEST" "${TAGS[@]}" << 'PYEOF'
import json, sys, os

slug = sys.argv[1]
title = sys.argv[2]
source_type = sys.argv[3]
timestamp = sys.argv[4]
raw_file = sys.argv[5]
manifest_path = sys.argv[6]
tags = list(sys.argv[7:])

# Validate manifest before touching anything else
try:
    with open(manifest_path, 'r') as f:
        manifest = json.load(f)
except FileNotFoundError:
    print(f'Error: {manifest_path} not found. Run /knowledge-vault:init first.')
    sys.exit(1)
except json.JSONDecodeError as e:
    print(f'Error: {manifest_path} is corrupt ({e}). Fix it before ingesting.')
    sys.exit(1)

# Escape title for YAML double-quoted scalar (backslash, then double-quote)
yaml_title = title.replace('\\', '\\\\').replace('"', '\\"')

# Build tags YAML array
if tags:
    tags_yaml = '[' + ', '.join('"' + t.replace('\\', '\\\\').replace('"', '\\"') + '"' for t in tags) + ']'
else:
    tags_yaml = '[]'

# Write raw file with YAML frontmatter
with open(raw_file, 'w') as f:
    f.write(f'---\n')
    f.write(f'title: "{yaml_title}"\n')
    f.write(f'source: ""\n')
    f.write(f'type: {source_type}\n')
    f.write(f'ingested: "{timestamp}"\n')
    f.write(f'tags: {tags_yaml}\n')
    f.write(f'compiled: false\n')
    f.write(f'---\n\n')

# Update manifest
manifest['sources'].append({
    'slug': slug,
    'title': title,
    'file': f'{slug}.md',
    'type': source_type,
    'ingested': timestamp,
    'compiled': False,
    'tags': tags
})

with open(manifest_path, 'w') as f:
    json.dump(manifest, f, indent=2)
PYEOF

echo "Created $RAW_FILE"
echo "Manifest updated. Claude will fill in the content body."
