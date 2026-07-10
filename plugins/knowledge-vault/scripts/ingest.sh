#!/bin/bash
# knowledge-vault: Create a raw source file and update the manifest.
# Usage: bash ingest.sh <slug> <title> <type> [tags...]

set -euo pipefail

VAULT_DIR=".vault"

if [ ! -d "$VAULT_DIR" ]; then
    echo "Error: No .vault/ directory found. Run the initialize workflow first."
    exit 1
fi

SLUG="${1:?Usage: ingest.sh <slug> <title> <type> [tags...]}"
TITLE="${2:?Missing title}"
TYPE="${3:?Missing type (paper|article|repo|dataset|meeting|notes|clip)}"
shift 3
TAGS=("$@")

if [[ ! "$SLUG" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
    echo "Error: slug must contain only letters, numbers, dots, underscores, and hyphens."
    exit 1
fi

case "$TYPE" in
    paper|article|repo|dataset|meeting|notes|clip|report|manual|filing|guideline) ;;
    *) echo "Error: unsupported source type '$TYPE'."; exit 1 ;;
esac

RAW_FILE="$VAULT_DIR/raw/$SLUG.md"
MANIFEST="$VAULT_DIR/raw/.manifest.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [ -f "$RAW_FILE" ]; then
    echo "Error: $RAW_FILE already exists."
    exit 1
fi

# Create raw file and update manifest via Python (safe against special chars in title)
python3 - "$SLUG" "$TITLE" "$TYPE" "$TIMESTAMP" "$RAW_FILE" "$MANIFEST" "${TAGS[@]}" << 'PYEOF'
import json, sys

slug = sys.argv[1]
title = sys.argv[2]
source_type = sys.argv[3]
timestamp = sys.argv[4]
raw_file = sys.argv[5]
manifest_path = sys.argv[6]
tags = list(sys.argv[7:])

# Validate the manifest before creating a raw file.
try:
    with open(manifest_path, 'r') as f:
        manifest = json.load(f)
except FileNotFoundError:
    print(f'Error: {manifest_path} not found. Run the initialize workflow first.')
    sys.exit(1)
except json.JSONDecodeError as error:
    print(f'Error: {manifest_path} is corrupt ({error}). Fix it before ingesting.')
    sys.exit(1)

if any(source.get('slug') == slug for source in manifest.get('sources', [])):
    print(f"Error: slug '{slug}' already exists in the manifest")
    sys.exit(1)

def yaml_esc(value):
    return value.replace('\\', '\\\\').replace('"', '\\"').replace('\n', ' ').replace('\r', ' ')

yaml_title = yaml_esc(title)

# Build tags YAML array
if tags:
    tags_yaml = '[' + ', '.join(f'"{yaml_esc(t)}"' for t in tags) + ']'
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
echo "Manifest updated. The host will fill in the content body."
