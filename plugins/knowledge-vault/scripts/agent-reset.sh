#!/bin/bash
# knowledge-vault: Reset agent.md to empty template.
# Usage: bash agent-reset.sh [vault-dir]

VAULT_DIR="${1:-.vault}"
AGENT_FILE="$VAULT_DIR/agent.md"

if [ ! -d "$VAULT_DIR" ]; then
    echo "No vault found at $VAULT_DIR"
    exit 1
fi

cat > "$AGENT_FILE" << 'EOF'
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

echo "Agent reset. Retrieval patterns cleared. The agent will re-learn from your next queries."
