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
   - **Sci-Hub** *(opt-in, per-project — a source for `/knowledge-vault:enrich-references`, usable on its own or alongside Unpaywall)*: follow the short disclosure sub-procedure in step 4a below.
   - **PageIndex** *(bundled, opt-in — auto-builds a hierarchical tree index for every ingested PDF; powers tier-3/4 of `/knowledge-vault:query`)*: follow the install sub-procedure in step 4b below.
4. Let user approve which servers to add. Run approved commands.

   **4a. If the user selects Sci-Hub, follow this sub-procedure (do NOT install otherwise):**

   i. Require `.vault/` in the current directory; if missing, tell the user to run `/knowledge-vault:init` first and skip Sci-Hub install.

   ii. If `.vault/.scihub-enabled` already exists AND an `mcp__scihub__*` tool is visible in this session, report `Sci-Hub is already enabled for this vault.` and skip.

   iii. Show the disclosure once, then ask the user to confirm:

   > ⚠️  **About Sci-Hub**
   >
   > Sci-Hub retrieves research papers by routing around publisher paywalls. Its legal status varies by jurisdiction. This plugin does not host or mirror Sci-Hub content — it only configures the third-party community MCP server [riichard/Sci-Hub-MCP-Server](https://github.com/riichard/Sci-Hub-MCP-Server) at **project scope only** (marker file: `.vault/.scihub-enabled`). You remain responsible for copyright compliance in your jurisdiction. Disable anytime with `rm .vault/.scihub-enabled && claude mcp remove scihub` from this directory.
   >
   > Proceed with the install?

   Treat any affirmative reply as confirmation (e.g. `yes`, `y`, `ok`, `sure`, `proceed`, `go`, `continue` — case-insensitive, whitespace tolerated). Treat a clearly negative reply (`no`, `n`, `cancel`, `stop`) as a cancellation: print `Sci-Hub install cancelled. No changes made.` and skip. When unclear, ask once more briefly; don't hard-block on exact wording.

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
        "disclosure_acknowledged": true
      }
      EOF'
      ```

   viii. Tell the user: `Sci-Hub MCP installed and registered for this project. Restart Claude Code so the new MCP tools are picked up, then re-run /knowledge-vault:enrich-references.`

   **4b. If the user selects PageIndex, follow this sub-procedure (do NOT install otherwise):**

   i. Verify the vendored PageIndex is present:
      ```bash
      test -f "${CLAUDE_PLUGIN_ROOT}/vendor/PageIndex/run_pageindex.py" \
        || { echo "PageIndex vendor missing — re-install the plugin"; exit 1; }
      ```

   ii. Verify `python3` is available (`command -v python3`); if missing, tell the user to install Python 3.10+ and skip.

   iii. Install the Python dependencies (one-time, permission prompt):
      ```bash
      pip3 install -r "${CLAUDE_PLUGIN_ROOT}/vendor/PageIndex/requirements.txt"
      ```

      If the user has multiple Python installs, suggest a venv: `python3 -m venv ~/.local/share/knowledge-vault/venv && ~/.local/share/knowledge-vault/venv/bin/pip install -r "${CLAUDE_PLUGIN_ROOT}/vendor/PageIndex/requirements.txt"` — but install globally by default for simplicity.

   iv. Confirm `ANTHROPIC_API_KEY` is set: `[ -n "$ANTHROPIC_API_KEY" ]`. **If unset: STOP here** — do NOT write the `.env` file (an empty `.env` makes detection report PageIndex as configured while every tree build silently fails). Tell the user to add `export ANTHROPIC_API_KEY=sk-ant-...` to their shell rc and re-run `/knowledge-vault:setup-sources`, then skip the remaining PageIndex steps and report it as not configured.

   v. Write a `.env` file in the vendored directory so PageIndex can pick up the key when invoked from a non-interactive shell (only reached when the key is confirmed non-empty):
      ```bash
      cat > "${CLAUDE_PLUGIN_ROOT}/vendor/PageIndex/.env" <<EOF
      ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY
      EOF
      chmod 600 "${CLAUDE_PLUGIN_ROOT}/vendor/PageIndex/.env"
      ```

      Note: the `.env` lives inside the plugin install; a plugin re-install/refresh can delete it. If trees silently stop building after an update, re-run this step.

   vi. Smoke test: ensure the runner executes without error.
      ```bash
      python3 "${CLAUDE_PLUGIN_ROOT}/vendor/PageIndex/run_pageindex.py" --help >/dev/null
      ```

   vii. Tell the user: `PageIndex set up. Every ingested PDF will now get a hierarchical tree index (raw/<slug>.tree.json) and a tree-derived markdown body — a typical 15-page paper takes ~30-45s and a few cents of Anthropic API cost per PDF. The originals/ folder preserves the source PDFs renamed by author-year-keyword.`

5. Update `.vault/sources.json` with the new configuration.

## Notes

- **Project scope is intentional for Sci-Hub**: the `-s project` flag writes to this project's `.mcp.json` so Sci-Hub is never enabled across all projects by default. This differs from how the other recommended MCPs are typically added.
- **No shell-rc edits**: the per-vault marker file (`.vault/.scihub-enabled`) is the opt-in gate, not an env var. The plugin does not modify `~/.bashrc` or `~/.zshrc`.
- **Disable Sci-Hub later**: `rm .vault/.scihub-enabled && claude mcp remove scihub` from the project directory.
- **Disable PageIndex later**: `rm "${CLAUDE_PLUGIN_ROOT}/vendor/PageIndex/.env"`. Subsequent ingests fall back to flat `pdftotext`+condense automatically (no command changes required).
- **PageIndex storage**: PDFs preserved across all vaults are renamed to `<author>-<year>-<keyword>.pdf` (or `<org>-<year>-<keyword>.pdf` for reports/manuals/filings/guidelines) and stored under each vault's `originals/` directory. Tree JSON sits at `raw/<slug>.tree.json`; the markdown body becomes a tree-derived outline.
