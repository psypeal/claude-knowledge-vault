---
description: Configure research MCP servers for academic collection
---

## Procedure

1. Run: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect-mcp-sources.sh"` to detect installed and available research servers.
2. Present results to user: which servers are installed (enabled) and which are available but not yet added.
3. For servers not installed, show the add command:
   - **Consensus**: `claude mcp add --transport http consensus https://mcp.consensus.app/mcp`
   - **arXiv**: `claude mcp add arxiv-mcp-server -- uvx arxiv-mcp-server --storage-path .vault/raw/arxiv-papers`
   - **Paper Search** (14 databases): `claude mcp add paper-search -- npx -y paper-search-mcp-nodejs`
   - **Zotero** (enables `/knowledge-vault:ingest-zotero`): `uv tool install zotero-mcp-server && zotero-mcp setup`
   - **Unpaywall** (enables `/knowledge-vault:enrich-references`): `export UNPAYWALL_EMAIL=you@example.com` — free, no signup; add to your shell rc to persist
4. Let user approve which servers to add. Run approved commands.
5. Update `.vault/sources.json` with the new configuration.
6. **Trailing tip** — if Unpaywall is now configured AND no Sci-Hub MCP is detected, print:
   > Optional: `/knowledge-vault:setup-scihub` adds a Sci-Hub fallback for papers Unpaywall can't find. Opt-in, with legal considerations — read the disclaimer before enabling.
