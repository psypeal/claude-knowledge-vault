#!/bin/bash
# knowledge-vault: Scan raw/ for reference-only items with a DOI.
# Output: JSON list of {slug, doi, file, title} candidates for fulltext enrichment.
# Used by /knowledge-vault:enrich-references.
# Usage: bash enrich-references.sh

set -euo pipefail

VAULT_DIR=".vault"

if [ ! -d "$VAULT_DIR/raw" ]; then
    echo '{"error": "No .vault/raw/ directory found. Run /knowledge-vault:init first."}'
    exit 1
fi

python3 - "$VAULT_DIR/raw" << 'PYEOF'
import json, os, re, sys

raw_dir = sys.argv[1]

def parse_frontmatter(content):
    if not content.startswith('---'):
        return None
    parts = content.split('---', 2)
    if len(parts) < 3:
        return None
    fm = {}
    for line in parts[1].strip().split('\n'):
        if ':' not in line:
            continue
        k, _, v = line.partition(':')
        fm[k.strip()] = v.strip().strip('"').strip("'")
    return fm

candidates = []
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
    has_fulltext = fm.get('has_fulltext', '').lower()
    doi = fm.get('doi', '').strip()
    if has_fulltext == 'false' and doi:
        candidates.append({
            'slug': fname[:-3],
            'doi': doi,
            'file': fpath,
            'title': fm.get('title', ''),
            'year': fm.get('year', ''),
        })

print(json.dumps({'candidates': candidates, 'count': len(candidates)}, indent=2))
PYEOF
