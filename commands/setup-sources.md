---
description: Configure research MCP servers for academic collection
---

Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect-mcp-sources.sh"` to detect currently installed and available research servers.

Present the detected and available servers to the user. For servers not yet installed, show the pre-built add command:

- **Consensus**: `claude mcp add --transport http consensus https://mcp.consensus.app/mcp`
- **arXiv**: `claude mcp add arxiv-mcp-server -- uvx arxiv-mcp-server --storage-path .vault/raw/arxiv-papers`
- **Paper Search** (14 databases): `claude mcp add paper-search -- npx -y paper-search-mcp-nodejs`

Let the user approve which servers to add. Run the approved commands, then update `.vault/sources.json` with the new configuration.
