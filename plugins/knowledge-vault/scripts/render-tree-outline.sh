#!/bin/bash
# knowledge-vault: Render a PageIndex tree.json as a markdown outline on stdout.
#   Top-level nodes  -> "## Title"
#   Child nodes      -> "### Title", "#### Title", ...
#   Each node's summary follows on the next line(s); empty summaries are skipped.
#   Page range (start_index..end_index, 1-indexed) is appended in italics if present.
# Usage: bash render-tree-outline.sh <tree.json>

set -euo pipefail

TREE_JSON="${1:?Usage: render-tree-outline.sh <tree.json>}"

if [ ! -f "$TREE_JSON" ]; then
    echo "Tree file not found: $TREE_JSON" >&2
    exit 1
fi

python3 - "$TREE_JSON" << 'PYEOF'
import json
import sys

tree_path = sys.argv[1]

try:
    with open(tree_path, 'r') as f:
        tree = json.load(f)
except json.JSONDecodeError as e:
    print(f'Error: {tree_path} is not valid JSON ({e}). Rebuild the tree via build-tree.sh.', file=sys.stderr)
    sys.exit(1)

# PageIndex top-level output is a list of nodes (with optional doc-description as a sibling node).
# Some configs return a dict { "doc_description": "...", "nodes": [...] }; handle both.
doc_description = None
if isinstance(tree, dict):
    doc_description = tree.get('doc_description')
    nodes = tree.get('nodes', tree.get('structure', []))
elif isinstance(tree, list):
    nodes = tree
else:
    nodes = []

out = []

if doc_description:
    out.append("## Overview")
    out.append("")
    out.append(doc_description.strip())
    out.append("")

def render(node, depth):
    title = node.get('title', '').strip() or '(untitled)'
    heading = '#' * min(max(depth, 2), 6)
    page_hint = ''
    s, e = node.get('start_index'), node.get('end_index')
    if s is not None and e is not None:
        page_hint = f"  *(pages {s}-{e})*"
    out.append(f"{heading} {title}{page_hint}")
    summary = (node.get('summary') or '').strip()
    if summary:
        out.append("")
        out.append(summary)
    out.append("")
    for child in node.get('nodes', []) or []:
        render(child, depth + 1)

for n in nodes:
    render(n, 2)

sys.stdout.write('\n'.join(out).rstrip() + '\n')
PYEOF
