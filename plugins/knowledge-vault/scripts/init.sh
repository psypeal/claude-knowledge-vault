#!/bin/bash
# knowledge-vault: Initialize a .vault/ knowledge base in the current project.
# Usage: bash init.sh [target-dir]
#   target-dir: project directory (defaults to current directory)

set -euo pipefail

TARGET="${1:-.}"
VAULT_DIR="$TARGET/.vault"
PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INSTRUCTIONS="$PLUGIN_DIR/assets/VAULT-INSTRUCTIONS.md"

if [ ! -f "$INSTRUCTIONS" ]; then
    echo "Error: plugin instructions missing at $INSTRUCTIONS" >&2
    exit 1
fi

ensure_project_instructions() {
    local filename target_file
    for filename in CLAUDE.md AGENTS.md; do
        target_file="$TARGET/$filename"
        if [ -f "$target_file" ]; then
            if ! grep -q "^## Knowledge Vault$" "$target_file" 2>/dev/null; then
                printf '\n' >> "$target_file"
                cat "$INSTRUCTIONS" >> "$target_file"
            fi
        else
            cat "$INSTRUCTIONS" > "$target_file"
        fi
    done
}

if [ -d "$VAULT_DIR" ]; then
    ensure_project_instructions
    echo "Vault already exists at $VAULT_DIR"
    exit 0
fi

# Create the vault directory structure.
mkdir -p "$VAULT_DIR"/{Clippings,inbox,originals,raw,wiki/{concepts,summaries,outputs},templates}

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

_No sources compiled yet. Add a source with the ingest workflow._

## Pending Compilation (0)

_No sources pending._

## Concepts (0)

_No concepts extracted yet. Run the compile workflow after ingesting sources._

## Recent Outputs

_No queries filed yet._
EOF

# Empty backlinks index
echo '{}' > "$VAULT_DIR/wiki/_backlinks.json"

# Empty sources config
cat > "$VAULT_DIR/sources.json" << 'EOF'
{
  "version": 1,
  "configured_sources": [],
  "last_configured": null
}
EOF

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

# Copy templates from plugin assets
if [ -d "$PLUGIN_DIR/assets/templates" ]; then
    cp "$PLUGIN_DIR/assets/templates"/*.md "$VAULT_DIR/templates/" 2>/dev/null || true
fi

ensure_project_instructions

echo "Vault initialized at $VAULT_DIR/"
echo "Open $VAULT_DIR/ as an Obsidian vault to browse the knowledge base."
