#!/bin/bash
# knowledge-vault: Scan raw/ for items missing original_path (v2.3 → v2.4 migration candidates).
# Categorizes each by best recovery method based on available frontmatter cues.
# Output: JSON with categorized lists.
# Usage: bash backfill-candidates.sh [vault-dir]

set -euo pipefail

VAULT_DIR="${1:-.vault}"

if [ ! -d "$VAULT_DIR/raw" ]; then
    echo '{"error": "No .vault/raw/ directory found. Run the initialize workflow first."}'
    exit 1
fi

python3 - "$VAULT_DIR" << 'PYEOF'
import json
import os
import sys

vault_dir = sys.argv[1]
raw_dir = os.path.join(vault_dir, 'raw')


def parse_frontmatter(content: str) -> dict | None:
    if not content.startswith('---'):
        return None
    parts = content.split('---', 2)
    if len(parts) < 3:
        return None
    fm: dict = {}
    for line in parts[1].strip().split('\n'):
        if ':' not in line:
            continue
        k, _, v = line.partition(':')
        fm[k.strip()] = v.strip().strip('"').strip("'")
    return fm


categorized = {
    'from_zotero': [],
    'from_doi': [],
    'from_url': [],
    'unrecoverable': [],
}

# Skippable types: clips/notes/meetings rarely have a canonical original PDF.
TARGET_TYPES = {'paper', 'article', 'report', 'manual', 'filing', 'guideline', 'dataset'}

for fname in sorted(os.listdir(raw_dir)):
    if not fname.endswith('.md') or fname.startswith('.'):
        continue
    fpath = os.path.join(raw_dir, fname)
    try:
        with open(fpath) as f:
            content = f.read()
    except Exception:
        continue
    fm = parse_frontmatter(content)
    if not fm:
        continue

    # Skip if already backfilled (idempotent).
    if fm.get('original_path', '').strip():
        # Confirm the file actually exists; if not, treat as still-missing.
        op = fm.get('original_path', '').strip()
        full = op if os.path.isabs(op) else os.path.join(vault_dir, op)
        if os.path.isfile(full):
            continue

    typ = fm.get('type', '').strip().lower()
    if typ not in TARGET_TYPES:
        continue

    slug = fname[:-3]
    title = fm.get('title', '')
    year = fm.get('year', '')

    zotero_key = fm.get('zotero_key', '').strip()
    doi = fm.get('doi', '').strip()
    src = fm.get('source', '').strip()

    item = {
        'slug': slug,
        'file': fpath,
        'title': title,
        'year': year,
        'type': typ,
    }

    # Recovery method priority: zotero > doi > url
    if zotero_key:
        item['zotero_key'] = zotero_key
        categorized['from_zotero'].append(item)
    elif doi:
        item['doi'] = doi
        categorized['from_doi'].append(item)
    elif src and (src.lower().endswith('.pdf') or '.pdf?' in src.lower()):
        item['source'] = src
        categorized['from_url'].append(item)
    else:
        item['source'] = src
        categorized['unrecoverable'].append(item)

result = {
    'categorized': categorized,
    'counts': {k: len(v) for k, v in categorized.items()},
    'total_missing': sum(len(v) for v in categorized.values()),
}
print(json.dumps(result, indent=2))
PYEOF
