#!/bin/bash
# knowledge-vault: Create a raw source file and update the manifest.
# Usage: bash ingest.sh <slug> <title> <type> [tags...]
#   slug:  lowercase-hyphenated identifier (e.g., "attention-is-all-you-need")
#   title: human-readable title (e.g., "Attention Is All You Need")
#   type:  paper|article|repo|dataset|meeting|notes|clip
#   tags:  optional space-separated tags

set -euo pipefail

VAULT_DIR=".vault"

if [ ! -d "$VAULT_DIR" ]; then
    echo "Error: No .vault/ directory found. Run 'vault init' first."
    exit 1
fi

SLUG="${1:?Usage: ingest.sh <slug> <title> <type> [tags...]}"
TITLE="${2:?Missing title}"
TYPE="${3:?Missing type (paper|article|repo|dataset|meeting|notes|clip)}"
shift 3
TAGS=("$@")

RAW_FILE="$VAULT_DIR/raw/$SLUG.md"
MANIFEST="$VAULT_DIR/raw/.manifest.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [ -f "$RAW_FILE" ]; then
    echo "Error: $RAW_FILE already exists."
    exit 1
fi

# Build tags YAML array
TAGS_YAML="[]"
if [ ${#TAGS[@]} -gt 0 ]; then
    TAGS_YAML="[$(printf '"%s", ' "${TAGS[@]}" | sed 's/, $//')]"
fi

# Create raw file with YAML frontmatter
cat > "$RAW_FILE" << FRONTMATTER
---
title: "$TITLE"
source: ""
type: $TYPE
ingested: "$TIMESTAMP"
tags: $TAGS_YAML
compiled: false
---

FRONTMATTER

# Update manifest using python3 (available on most systems)
python3 -c "
import json, sys

manifest_path = '$MANIFEST'
with open(manifest_path, 'r') as f:
    manifest = json.load(f)

manifest['sources'].append({
    'slug': '$SLUG',
    'title': '$TITLE',
    'file': '$SLUG.md',
    'type': '$TYPE',
    'ingested': '$TIMESTAMP',
    'compiled': False,
    'tags': $TAGS_YAML
})

with open(manifest_path, 'w') as f:
    json.dump(manifest, f, indent=2)
"

echo "Created $RAW_FILE"
echo "Manifest updated. Claude will fill in the content body."
