#!/bin/bash
# knowledge-vault: Rebuild wiki/index.md and wiki/_backlinks.json from file frontmatter.
# Replaces Claude reading every file (~26K-60K+ tokens) with a free script call.
# Usage: bash rebuild-index.sh [vault-dir]

set -euo pipefail

VAULT_DIR="${1:-.vault}"
WIKI="$VAULT_DIR/wiki"
INDEX="$WIKI/index.md"
BACKLINKS="$WIKI/_backlinks.json"
MANIFEST="$VAULT_DIR/raw/.manifest.json"
STATE="$WIKI/.state.json"

export VAULT_DIR

python3 << 'PYEOF'
import json, os, re, sys, glob
from datetime import datetime, timezone

vault = os.environ.get("VAULT_DIR", ".vault")
wiki = f"{vault}/wiki"
manifest_path = f"{vault}/raw/.manifest.json"
state_path = f"{wiki}/.state.json"
index_path = f"{wiki}/index.md"
backlinks_path = f"{wiki}/_backlinks.json"

def parse_frontmatter(filepath):
    """Extract YAML frontmatter as dict from a markdown file."""
    try:
        with open(filepath, 'r') as f:
            content = f.read()
    except:
        return {}
    if not content.startswith('---'):
        return {}
    parts = content.split('---', 2)
    if len(parts) < 3:
        return {}
    fm = {}
    for line in parts[1].strip().split('\n'):
        if ':' in line:
            key, _, val = line.partition(':')
            key = key.strip()
            val = val.strip().strip('"').strip("'")
            # Handle arrays
            if val.startswith('['):
                try:
                    fm[key] = json.loads(val.replace("'", '"'))
                except:
                    fm[key] = [v.strip().strip('"') for v in val.strip('[]').split(',') if v.strip()]
            else:
                fm[key] = val
    return fm

def extract_wikilinks(filepath):
    """Extract all [[wikilinks]] from a file."""
    try:
        with open(filepath, 'r') as f:
            content = f.read()
    except:
        return []
    return re.findall(r'\[\[([^\]]+)\]\]', content)

def get_body(filepath):
    """Return file content minus YAML frontmatter."""
    try:
        with open(filepath, 'r') as f:
            content = f.read()
    except:
        return ''
    if content.startswith('---'):
        parts = content.split('---', 2)
        if len(parts) >= 3:
            return parts[2]
    return content

# --- Read manifest ---
with open(manifest_path, 'r') as f:
    manifest = json.load(f)

sources = manifest.get('sources', [])
compiled_sources = [s for s in sources if s.get('compiled')]
pending_sources = [s for s in sources if not s.get('compiled')]

# --- Scan summaries ---
summary_rows = []
summaries_without_wikilinks = []
for s in compiled_sources:
    slug = s['slug']
    summary_path = f"{wiki}/summaries/{slug}.md"
    fm = parse_frontmatter(summary_path)
    concepts = fm.get('concepts_extracted', [])
    if isinstance(concepts, str):
        concepts = [c.strip() for c in concepts.strip('[]').split(',') if c.strip()]
    concept_links = ', '.join(f'[[{c}]]' for c in concepts[:4])
    summary_rows.append({
        'slug': slug,
        'type': s.get('type', '?'),
        'title': s.get('title', slug),
        'concepts': concept_links,
        'ingested': s.get('ingested', '')
    })
    # Robustness check: compiled summary should link to at least one concept.
    # Parses only the body (not frontmatter) so concepts: [...] metadata doesn't count.
    if os.path.exists(summary_path):
        body = get_body(summary_path)
        if not re.search(r'\[\[[^\]]+\]\]', body):
            summaries_without_wikilinks.append(slug)

# Sort by ingestion date (newest first)
summary_rows.sort(key=lambda x: x['ingested'], reverse=True)

# --- Scan concepts ---
concept_rows = []
concept_files = glob.glob(f"{wiki}/concepts/*.md")
for cf in sorted(concept_files):
    fm = parse_frontmatter(cf)
    slug = os.path.splitext(os.path.basename(cf))[0]
    sources_list = fm.get('sources', [])
    if isinstance(sources_list, str):
        sources_list = [s.strip() for s in sources_list.strip('[]').split(',') if s.strip()]
    title = fm.get('title', slug)
    concept_rows.append({
        'slug': slug,
        'title': title,
        'source_count': len(sources_list)
    })

concept_rows.sort(key=lambda x: x['title'].lower())

# --- Scan outputs ---
output_files = glob.glob(f"{wiki}/outputs/*.md")
# Filter out lint reports from output count
non_lint_outputs = [f for f in output_files if not os.path.basename(f).startswith('lint-')]
total_output_count = len(non_lint_outputs)

# Display only 5 most recent, but count ALL for stats
output_rows = []
for of in sorted(output_files, key=os.path.getmtime, reverse=True)[:5]:
    fm = parse_frontmatter(of)
    slug = os.path.splitext(os.path.basename(of))[0]
    title = fm.get('title', slug)
    created = fm.get('created', '')
    output_rows.append({'slug': slug, 'title': title, 'created': created})

# --- Build index.md ---
now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
lines = [
    '---',
    'title: Vault Index',
    f'updated: "{now}"',
    '---',
    '',
    '# Vault Index',
    '',
    f'## Source Summaries ({len(compiled_sources)} compiled)',
    ''
]

if summary_rows:
    lines.append('| Source | Type | Concepts |')
    lines.append('|--------|------|----------|')
    for r in summary_rows:
        lines.append(f'| [{r["title"]}](summaries/{r["slug"]}.md) | {r["type"]} | {r["concepts"]} |')
else:
    lines.append('_No sources compiled yet._')

lines.extend([
    '',
    f'## Pending Compilation ({len(pending_sources)})',
    ''
])

if pending_sources:
    for s in pending_sources:
        lines.append(f'- `{s["slug"]}` ({s.get("type", "?")})')
else:
    lines.append('_No sources pending._')

lines.extend([
    '',
    f'## Concepts ({len(concept_rows)})',
    ''
])

if concept_rows:
    lines.append('| Concept | Sources |')
    lines.append('|---------|---------|')
    for c in concept_rows:
        lines.append(f'| [{c["title"]}](concepts/{c["slug"]}.md) | {c["source_count"]} |')
else:
    lines.append('_No concepts extracted yet._')

lines.extend([
    '',
    '## Recent Outputs',
    ''
])

if output_rows:
    for o in output_rows:
        lines.append(f'- [{o["title"]}](outputs/{o["slug"]}.md) ({o["created"][:10]})')
else:
    lines.append('_No queries filed yet._')

with open(index_path, 'w') as f:
    f.write('\n'.join(lines) + '\n')

# --- Build _backlinks.json ---
backlinks = {}
all_md_files = (
    glob.glob(f"{wiki}/concepts/*.md") +
    glob.glob(f"{wiki}/summaries/*.md") +
    glob.glob(f"{wiki}/outputs/*.md")
)

for md_file in all_md_files:
    source_slug = os.path.splitext(os.path.basename(md_file))[0]
    links = extract_wikilinks(md_file)
    for link in links:
        link_slug = link.lower().replace(' ', '-')
        if link_slug not in backlinks:
            backlinks[link_slug] = []
        if source_slug not in backlinks[link_slug]:
            backlinks[link_slug].append(source_slug)

with open(backlinks_path, 'w') as f:
    json.dump(backlinks, f, indent=2)

# --- Update .state.json ---
try:
    with open(state_path, 'r') as f:
        state = json.load(f)
except:
    state = {"version": 1}

state['stats'] = {
    'source_count': len(sources),
    'compiled_count': len(compiled_sources),
    'pending_count': len(pending_sources),
    'concept_count': len(concept_rows),
    'summary_count': len(compiled_sources),
    'output_count': total_output_count
}
# Do NOT overwrite last_compiled here — that is set only by the compile command
# via update-state.sh. Rebuild is called by lint, cleanup, and compile alike.
state['last_rebuilt'] = now

with open(state_path, 'w') as f:
    json.dump(state, f, indent=2)

print(f"Index rebuilt: {len(compiled_sources)} sources, {len(concept_rows)} concepts, {len(output_rows)} outputs")

if summaries_without_wikilinks:
    print(f"\nWarning: {len(summaries_without_wikilinks)} compiled summaries have no wikilinks to concepts:", file=sys.stderr)
    for slug in summaries_without_wikilinks:
        print(f"  - wiki/summaries/{slug}.md", file=sys.stderr)
    print("  These summaries are disconnected from the concept graph.", file=sys.stderr)
    print("  Fix: re-run /knowledge-vault:compile <slug> or /knowledge-vault:cleanup.", file=sys.stderr)
PYEOF
