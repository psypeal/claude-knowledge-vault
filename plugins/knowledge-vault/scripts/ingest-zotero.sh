#!/bin/bash
# knowledge-vault: Create a raw source file from a Zotero item.
# Adds Zotero-specific frontmatter (zotero_key, citekey, doi, year, authors, has_fulltext).
# Usage: bash ingest-zotero.sh <slug> <title> <zotero_key> <citekey> <doi> <year> <authors_csv> [type] [has_fulltext] [tags...]
#   type:         paper|article|report|manual|filing|guideline|dataset (default: paper)
#   has_fulltext: true|false (default: false — flip to true when fulltext was fetched)

set -euo pipefail

VAULT_DIR=".vault"

if [ ! -d "$VAULT_DIR" ]; then
    echo "Error: No .vault/ directory found. Run /knowledge-vault:init first."
    exit 1
fi

SLUG="${1:?Usage: ingest-zotero.sh <slug> <title> <zotero_key> <citekey> <doi> <year> <authors_csv> [type] [has_fulltext] [tags...]}"
TITLE="${2:?Missing title}"
ZOTERO_KEY="${3:?Missing zotero_key}"
CITEKEY="${4:-}"
DOI="${5:-}"
YEAR="${6:-}"
AUTHORS="${7:-}"
TYPE="${8:-paper}"
HAS_FULLTEXT="${9:-false}"
if [ $# -ge 9 ]; then
    shift 9
else
    shift $#
fi
TAGS=("$@")

RAW_FILE="$VAULT_DIR/raw/$SLUG.md"
MANIFEST="$VAULT_DIR/raw/.manifest.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [ -f "$RAW_FILE" ]; then
    echo "Skipped: $RAW_FILE already exists."
    exit 0
fi

python3 - "$SLUG" "$TITLE" "$ZOTERO_KEY" "$CITEKEY" "$DOI" "$YEAR" "$AUTHORS" "$TYPE" "$HAS_FULLTEXT" "$TIMESTAMP" "$RAW_FILE" "$MANIFEST" "${TAGS[@]}" << 'PYEOF'
import json, sys

(slug, title, zotero_key, citekey, doi, year, authors_csv,
 source_type, has_fulltext, timestamp, raw_file, manifest_path) = sys.argv[1:13]
tags = list(sys.argv[13:])

# Validate manifest before writing anything — no orphaned raw files
try:
    with open(manifest_path, 'r') as f:
        manifest = json.load(f)
except FileNotFoundError:
    print(f'Error: {manifest_path} not found. Run /knowledge-vault:init first.')
    sys.exit(1)
except json.JSONDecodeError as e:
    print(f'Error: {manifest_path} is corrupt ({e}). Fix it before ingesting.')
    sys.exit(1)

def yaml_esc(s):
    return s.replace('\\', '\\\\').replace('"', '\\"')

has_fulltext = 'true' if has_fulltext.lower() == 'true' else 'false'

authors = [a.strip() for a in authors_csv.split('|') if a.strip()] if authors_csv else []
authors_yaml = '[' + ', '.join(f'"{yaml_esc(a)}"' for a in authors) + ']' if authors else '[]'

tags_yaml = '[' + ', '.join(f'"{yaml_esc(t)}"' for t in tags) + ']' if tags else '[]'

source_val = f'https://doi.org/{doi}' if doi else f'zotero://select/library/items/{zotero_key}'

with open(raw_file, 'w') as f:
    f.write('---\n')
    f.write(f'title: "{yaml_esc(title)}"\n')
    f.write(f'source: "{yaml_esc(source_val)}"\n')
    f.write(f'type: {source_type}\n')
    f.write(f'ingested: "{timestamp}"\n')
    f.write(f'tags: {tags_yaml}\n')
    f.write('compiled: false\n')
    f.write(f'has_fulltext: {has_fulltext}\n')
    f.write(f'zotero_key: "{yaml_esc(zotero_key)}"\n')
    if citekey:
        f.write(f'citekey: "{yaml_esc(citekey)}"\n')
    if doi:
        f.write(f'doi: "{yaml_esc(doi)}"\n')
    if year:
        f.write(f'year: "{yaml_esc(year)}"\n')
    f.write(f'authors: {authors_yaml}\n')
    f.write('---\n\n')

manifest['sources'].append({
    'slug': slug,
    'title': title,
    'file': f'{slug}.md',
    'type': source_type,
    'ingested': timestamp,
    'compiled': False,
    'tags': tags,
    'zotero_key': zotero_key,
})

with open(manifest_path, 'w') as f:
    json.dump(manifest, f, indent=2)
PYEOF

echo "Created $RAW_FILE"
