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
   - **Sci-Hub** *(opt-in, per-project — fallback for `/knowledge-vault:enrich-references` when Unpaywall misses)*: requires the explicit-consent sub-procedure in step 4a below.
4. Let user approve which servers to add. Run approved commands.

   **4a. If the user selects Sci-Hub, follow this sub-procedure (do NOT install otherwise):**

   i. Require `.vault/` in the current directory; if missing, tell the user to run `/knowledge-vault:init` first and skip Sci-Hub install.

   ii. If `.vault/.scihub-enabled` already exists AND an `mcp__scihub__*` tool is visible in this session, report `Sci-Hub fallback is already enabled for this vault.` and skip.

   iii. Print the disclaimer **verbatim** and require an explicit `yes`:

   > ⚠️  **Sci-Hub fallback — read before enabling**
   >
   > Sci-Hub provides access to research papers by routing around publisher paywalls.
   > Its legal status varies by jurisdiction; some countries and institutions block
   > access. By enabling this integration you acknowledge:
   >
   > 1. You are responsible for complying with copyright law in your jurisdiction.
   > 2. This plugin neither hosts nor mirrors Sci-Hub content — it only configures a
   >    third-party community MCP server (riichard/Sci-Hub-MCP-Server) on your machine.
   > 3. The Sci-Hub MCP is enabled **only for this project** (`.vault/.scihub-enabled`
   >    marker). To enable it elsewhere, re-run `/knowledge-vault:setup-sources` and
   >    select Sci-Hub in each project.
   > 4. You can disable it anytime by deleting `.vault/.scihub-enabled` and running
   >    `claude mcp remove scihub` from this directory.

   If the user does not reply exactly `yes` (case-insensitive), print `Sci-Hub install cancelled. No changes made.` and skip.

   iv. Verify `uv` is available (`command -v uv`); if missing, tell the user to install it (`curl -LsSf https://astral.sh/uv/install.sh | sh`) and re-run, then skip Sci-Hub install.

   v. Run the install (permission prompt):
      ```bash
      uv tool install "sci-hub-mcp-server @ git+https://github.com/riichard/Sci-Hub-MCP-Server"
      ```

   vi. Register at **project scope only** (permission prompt):
      ```bash
      claude mcp add scihub -s project -- sci-hub-mcp --transport stdio
      ```

   vii. Write the per-vault marker:
      ```bash
      bash -c 'cat > .vault/.scihub-enabled <<EOF
      {
        "enabled_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
        "mcp_source": "github.com/riichard/Sci-Hub-MCP-Server",
        "disclaimer_acknowledged": true
      }
      EOF'
      ```

   viii. Tell the user: `Sci-Hub MCP installed and registered for this project. Restart Claude Code so the new MCP tools are picked up, then re-run /knowledge-vault:enrich-references.`

5. Update `.vault/sources.json` with the new configuration.

## Notes

- **Project scope is intentional for Sci-Hub**: the `-s project` flag writes to this project's `.mcp.json` so Sci-Hub is never enabled across all projects by default. This differs from how the other recommended MCPs are typically added.
- **No shell-rc edits**: the per-vault marker file (`.vault/.scihub-enabled`) is the opt-in gate, not an env var. The plugin does not modify `~/.bashrc` or `~/.zshrc`.
- **Disable Sci-Hub later**: `rm .vault/.scihub-enabled && claude mcp remove scihub` from the project directory.
