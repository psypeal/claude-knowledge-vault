#!/bin/bash
# knowledge-vault: Run mechanical lint checks via script (no tokens).
# Handles checks 2-6 (incl. alias overlap), 8, and 9a/9b (originals + tree integrity).
# Outputs a markdown report.
# Usage: bash lint-checks.sh [vault-dir]

set -euo pipefail

VAULT_DIR="${1:-.vault}"

export VAULT_DIR

python3 << 'PYEOF'
import json, os, re, glob

vault = os.environ.get("VAULT_DIR", ".vault")
wiki = f"{vault}/wiki"
manifest_path = f"{vault}/raw/.manifest.json"
agent_path = f"{vault}/agent.md"

findings = {"stale": [], "missing_concepts": [], "orphaned": [], "thin": [], "duplicate_aliases": [], "agent_stale": [], "originals": [], "trees": []}

def parse_frontmatter(filepath):
    try:
        with open(filepath, 'r') as f:
            content = f.read()
    except:
        return {}, ""
    if not content.startswith('---'):
        return {}, content
    parts = content.split('---', 2)
    if len(parts) < 3:
        return {}, content
    fm = {}
    for line in parts[1].strip().split('\n'):
        if ':' in line:
            key, _, val = line.partition(':')
            key = key.strip()
            val = val.strip().strip('"').strip("'")
            if val.startswith('['):
                try:
                    fm[key] = json.loads(val.replace("'", '"'))
                except:
                    fm[key] = [v.strip().strip('"') for v in val.strip('[]').split(',') if v.strip()]
            else:
                fm[key] = val
    return fm, parts[2] if len(parts) > 2 else ""

# Load manifest
try:
    with open(manifest_path) as f:
        manifest = json.load(f)
    source_slugs = {s['slug'] for s in manifest.get('sources', [])}
    compiled_slugs = {s['slug'] for s in manifest.get('sources', []) if s.get('compiled')}
except:
    source_slugs, compiled_slugs = set(), set()

# Scan concepts
concept_files = glob.glob(f"{wiki}/concepts/*.md")
concept_slugs = set()
all_aliases = {}

for cf in concept_files:
    slug = os.path.splitext(os.path.basename(cf))[0]
    concept_slugs.add(slug)
    fm, body = parse_frontmatter(cf)

    # Check 2: Stale
    updated = fm.get('updated', '')
    sources = fm.get('sources', [])
    if isinstance(sources, str):
        sources = [s.strip() for s in sources.strip('[]').split(',') if s.strip()]
    # If concept has sources but no updated date, flag it
    if sources and not updated:
        findings["stale"].append(f"{slug}: no updated date but has {len(sources)} sources")

    # Check 4: Orphaned (zero sources)
    if not sources:
        findings["orphaned"].append(f"concepts/{slug}.md: zero sources linked")

    # Check 5: Thin
    word_count = len(body.split())
    if word_count < 100:
        findings["thin"].append(f"concepts/{slug}.md: {word_count} words (min 100)")

    # Check 6: Collect aliases for duplicate detection
    aliases = fm.get('aliases', [])
    if isinstance(aliases, str):
        aliases = [a.strip() for a in aliases.strip('[]').split(',') if a.strip()]
    title = fm.get('title', slug)
    all_aliases[slug] = set([title.lower()] + [a.lower() for a in aliases])

# Check 3: Missing concepts (wikilinks to non-existent articles)
all_md_files = glob.glob(f"{wiki}/concepts/*.md") + glob.glob(f"{wiki}/summaries/*.md") + glob.glob(f"{wiki}/outputs/*.md")
referenced = set()
for md_file in all_md_files:
    try:
        with open(md_file) as f:
            content = f.read()
        links = re.findall(r'\[\[([^\]]+)\]\]', content)
        for link in links:
            link_slug = link.lower().replace(' ', '-')
            referenced.add(link_slug)
    except:
        pass

for ref in referenced:
    if ref not in concept_slugs and not os.path.exists(f"{wiki}/summaries/{ref}.md"):
        findings["missing_concepts"].append(f"[[{ref}]]: referenced but no article exists")

# Check 4 continued: Summaries whose raw file is missing
summary_files = glob.glob(f"{wiki}/summaries/*.md")
for sf in summary_files:
    slug = os.path.splitext(os.path.basename(sf))[0]
    if slug not in source_slugs:
        findings["orphaned"].append(f"summaries/{slug}.md: raw source missing from manifest")

# Check 6: Duplicate alias overlap
slugs = list(all_aliases.keys())
for i in range(len(slugs)):
    for j in range(i+1, len(slugs)):
        overlap = all_aliases[slugs[i]] & all_aliases[slugs[j]]
        if overlap:
            findings["duplicate_aliases"].append(f"{slugs[i]} <-> {slugs[j]}: shared aliases {overlap}")

# Check 9: originals/ and tree.json integrity (v2.4)
raw_dir = f"{vault}/raw"
originals_dir = f"{vault}/originals"
raw_files = glob.glob(f"{raw_dir}/*.md")
raw_slug_set = set()
for rf in raw_files:
    slug = os.path.splitext(os.path.basename(rf))[0]
    raw_slug_set.add(slug)
    fm, _ = parse_frontmatter(rf)
    op = fm.get('original_path', '')
    if op:
        # Resolve relative paths against vault root
        full = op if os.path.isabs(op) else f"{vault}/{op}"
        if not os.path.isfile(full):
            findings["originals"].append(f"raw/{slug}.md: original_path '{op}' not found on disk")
    has_tree = str(fm.get('has_tree', '')).lower() == 'true'
    if has_tree:
        tree_path = f"{raw_dir}/{slug}.tree.json"
        if not os.path.isfile(tree_path):
            findings["trees"].append(f"raw/{slug}.md: has_tree:true but {slug}.tree.json missing")
        else:
            # quick JSON sanity
            try:
                with open(tree_path) as f:
                    json.load(f)
            except Exception as e:
                findings["trees"].append(f"raw/{slug}.tree.json: invalid JSON ({e})")

# Orphan originals: file in originals/ with no matching raw/<slug>.md
if os.path.isdir(originals_dir):
    for fname in os.listdir(originals_dir):
        slug = os.path.splitext(fname)[0]
        if slug and slug not in raw_slug_set:
            findings["originals"].append(f"originals/{fname}: no matching raw/{slug}.md")

# Check 8: Agent staleness
if os.path.exists(agent_path):
    try:
        with open(agent_path) as f:
            agent_content = f.read()
        # Check for concept/source references that don't exist
        agent_refs = re.findall(r'[\w-]+(?=[\s,|])', agent_content)
        for ref in agent_refs:
            if len(ref) > 3 and ref not in concept_slugs and ref not in source_slugs:
                # Only flag if it looks like a slug (has hyphens)
                if '-' in ref and ref not in ['no-clusters', 'no-patterns', 'no-source', 'no-corrections']:
                    findings["agent_stale"].append(f"agent.md references '{ref}': not found in vault")
    except:
        pass

# Count totals
warnings = (
    len(findings["stale"]) + len(findings["missing_concepts"]) + len(findings["orphaned"])
    + len(findings["duplicate_aliases"]) + len(findings["agent_stale"])
    + len(findings["originals"]) + len(findings["trees"])
)
suggestions = len(findings["thin"])

# Output report
report = []
report.append("## Automated Lint Checks\n")

if findings["stale"]:
    report.append(f"### Check 2: Stale Articles ({len(findings['stale'])} found) — Warning")
    for f in findings["stale"]:
        report.append(f"- {f}")
    report.append("")

if findings["missing_concepts"]:
    report.append(f"### Check 3: Missing Concepts ({len(findings['missing_concepts'])} found) — Warning")
    for f in findings["missing_concepts"]:
        report.append(f"- {f}")
    report.append("")

if findings["orphaned"]:
    report.append(f"### Check 4: Orphaned Articles ({len(findings['orphaned'])} found) — Warning")
    for f in findings["orphaned"]:
        report.append(f"- {f}")
    report.append("")

if findings["thin"]:
    report.append(f"### Check 5: Thin Articles ({len(findings['thin'])} found) — Suggestion")
    for f in findings["thin"]:
        report.append(f"- {f}")
    report.append("")

if findings["duplicate_aliases"]:
    report.append(f"### Check 6: Duplicate Aliases ({len(findings['duplicate_aliases'])} found) — Warning")
    for f in findings["duplicate_aliases"]:
        report.append(f"- {f}")
    report.append("")

if findings["agent_stale"]:
    report.append(f"### Check 8: Agent Staleness ({len(findings['agent_stale'])} found) — Warning")
    for f in findings["agent_stale"]:
        report.append(f"- {f}")
    report.append("")

if findings["originals"]:
    report.append(f"### Check 9a: Originals integrity ({len(findings['originals'])} found) — Warning")
    for f in findings["originals"]:
        report.append(f"- {f}")
    report.append("")

if findings["trees"]:
    report.append(f"### Check 9b: Tree integrity ({len(findings['trees'])} found) — Warning")
    for f in findings["trees"]:
        report.append(f"- {f}")
    report.append("")

if warnings == 0 and suggestions == 0:
    report.append("All automated checks passed.\n")

report.append(f"**Automated totals: {warnings} warnings, {suggestions} suggestions.**")
report.append("")
report.append("Checks 1 (contradictions) and 7 (gap analysis) require Claude — see below.")

print('\n'.join(report))
PYEOF
