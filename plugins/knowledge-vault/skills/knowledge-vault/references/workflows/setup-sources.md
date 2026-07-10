Before running a helper, set `KV_PLUGIN_ROOT` to `CLAUDE_PLUGIN_ROOT` when available; otherwise resolve the absolute plugin directory two levels above the parent `skills/knowledge-vault/SKILL.md`. Substitute that absolute path in each command.

## Procedure

1. Require `.vault/`. If it is absent, offer to initialize the vault first.
2. Run `bash "${KV_PLUGIN_ROOT}/scripts/detect-mcp-sources.sh"` and summarize detected and available sources.
3. Ask which sources to configure. Do not install or register anything without approval.
4. Use the command for the active host:

| Source | Claude Code | Codex |
|---|---|---|
| Consensus | `claude mcp add --transport http consensus https://mcp.consensus.app/mcp` | `codex mcp add consensus --url https://mcp.consensus.app/mcp` |
| arXiv | `claude mcp add arxiv-mcp-server -- uvx arxiv-mcp-server --storage-path .vault/raw/arxiv-papers` | `codex mcp add arxiv-mcp-server -- uvx arxiv-mcp-server --storage-path .vault/raw/arxiv-papers` |
| Paper Search | `claude mcp add paper-search -- npx -y paper-search-mcp-nodejs` | `codex mcp add paper-search -- npx -y paper-search-mcp-nodejs` |
| Zotero | Install with `uv tool install zotero-mcp-server`, then `claude mcp add zotero -- zotero-mcp` | Install with `uv tool install zotero-mcp-server`, then `codex mcp add zotero --env ZOTERO_LOCAL=true -- zotero-mcp` |
| Unpaywall | Set `UNPAYWALL_EMAIL` in the user's environment | Same |

5. After registration, tell the user to start a new host session before testing newly added MCP tools.
6. Update `.vault/sources.json` with only sources that were successfully configured. Follow [`../sources-json-schema.md`](../sources-json-schema.md).

## Sci-Hub (optional)

Run this section only when the user explicitly selects Sci-Hub.

1. If `.vault/.scihub-enabled` exists and an `mcp__scihub__*` tool is available, report that it is already enabled.
2. Show this disclosure and wait for explicit confirmation:

   > Sci-Hub routes around publisher paywalls, and its legal status varies by jurisdiction. Knowledge Vault does not host Sci-Hub content; it can configure the third-party `riichard/Sci-Hub-MCP-Server`. Claude Code can register it at project scope. The current Codex CLI registers MCP servers in the user configuration, while Knowledge Vault's `.vault/.scihub-enabled` marker still gates use to this vault. You are responsible for copyright compliance. Proceed?

3. If declined, make no changes. If approved, require `uv`, then run:

   ```bash
   uv tool install "sci-hub-mcp-server @ git+https://github.com/riichard/Sci-Hub-MCP-Server"
   ```

4. Register it for the active host:

   ```bash
   # Claude Code: project-scoped
   claude mcp add scihub -s project -- sci-hub-mcp --transport stdio

   # Codex: user-scoped; the per-vault marker below gates plugin use
   codex mcp add scihub -- sci-hub-mcp --transport stdio
   ```

5. After successful registration, write the marker:

   ```bash
   printf '{"enabled_at":"%s","mcp_source":"github.com/riichard/Sci-Hub-MCP-Server","disclosure_acknowledged":true}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > .vault/.scihub-enabled
   ```

To disable, remove `.vault/.scihub-enabled`, then run `claude mcp remove scihub` or `codex mcp remove scihub` for the active host.

## PageIndex (optional)

Run this section only when the user explicitly selects PDF tree indexing.

1. Require `git` and Python 3.
2. Install the pinned upstream PageIndex revision and its isolated environment:

   ```bash
   bash "${KV_PLUGIN_ROOT}/scripts/setup-pageindex.sh"
   ```

3. Require one supported model credential in the user's environment:

   - `OPENAI_API_KEY`: defaults to `openai/gpt-5.4-mini`.
   - `ANTHROPIC_API_KEY`: defaults to `anthropic/claude-sonnet-4-6`.
   - `KNOWLEDGE_VAULT_PAGEINDEX_MODEL`: optional LiteLLM model override.

   Never copy API keys into the plugin directory or vault files.

The installer pins PageIndex to a reviewed upstream revision under `~/.local/share/knowledge-vault/`. PDF ingestion builds `.vault/raw/<slug>.tree.json` when the install and credential are available; otherwise it falls back to normal text extraction.
