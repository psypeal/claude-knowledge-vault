#!/bin/bash
# knowledge-vault: Initialize a .vault/ knowledge base in the current project.
# Usage: bash init.sh [target-dir]
#   target-dir: project directory (defaults to current directory)

set -euo pipefail

TARGET="${1:-.}"
VAULT_DIR="$TARGET/.vault"
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [ -d "$VAULT_DIR" ]; then
    echo "Vault already exists at $VAULT_DIR"
    exit 1
fi

# Create directory structure
mkdir -p "$VAULT_DIR"/{Clippings,raw,wiki/{concepts,summaries,outputs},templates}

# Empty manifest
cat > "$VAULT_DIR/raw/.manifest.json" << 'EOF'
{
  "version": 1,
  "sources": []
}
EOF

# Empty wiki state
cat > "$VAULT_DIR/wiki/.state.json" << 'EOF'
{
  "version": 1,
  "last_compiled": null,
  "last_lint": null,
  "stats": {
    "source_count": 0,
    "compiled_count": 0,
    "pending_count": 0,
    "concept_count": 0,
    "summary_count": 0,
    "output_count": 0
  }
}
EOF

# Initial wiki index
cat > "$VAULT_DIR/wiki/index.md" << 'EOF'
---
title: Vault Index
updated: null
---

# Vault Index

## Source Summaries (0 compiled)

_No sources compiled yet. Use `vault ingest` to add sources._

## Pending Compilation (0)

_No sources pending._

## Concepts (0)

_No concepts extracted yet. Use `vault compile` after ingesting sources._

## Recent Outputs

_No queries filed yet._
EOF

# Empty backlinks index
echo '{}' > "$VAULT_DIR/wiki/_backlinks.json"

# Create empty agent.md
cat > "$VAULT_DIR/agent.md" << 'EOF'
---
title: Vault Agent
version: 1
updated: null
vault_stats:
  total_queries: 0
  total_compiles: 0
  cache_hits: 0
  tier3_fallbacks: 0
---

## Concept Clusters

_No clusters discovered yet._

## Query Patterns

_No patterns recorded yet._

## Source Signals

_No source signals yet._

## Corrections

_No corrections logged._
EOF

# Copy templates from skill assets
if [ -d "$SKILL_DIR/assets/templates" ]; then
    cp "$SKILL_DIR/assets/templates"/*.md "$VAULT_DIR/templates/" 2>/dev/null || true
fi

# Append CLAUDE.md addendum if not already present
CLAUDE_MD="$TARGET/CLAUDE.md"
if [ -f "$CLAUDE_MD" ]; then
    if ! grep -q "## Knowledge Vault" "$CLAUDE_MD" 2>/dev/null; then
        echo "" >> "$CLAUDE_MD"
        cat "$SKILL_DIR/assets/VAULT-CLAUDE.md" >> "$CLAUDE_MD"
    fi
else
    cat "$SKILL_DIR/assets/VAULT-CLAUDE.md" > "$CLAUDE_MD"
fi

echo "Vault initialized at $VAULT_DIR/"
echo "Open $VAULT_DIR/ as an Obsidian vault to browse the knowledge base."
