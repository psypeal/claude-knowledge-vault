---
description: Install and enable the Sci-Hub MCP fallback for this project (opt-in)
---

## Procedure

This command installs [riichard/Sci-Hub-MCP-Server](https://github.com/riichard/Sci-Hub-MCP-Server) as an **opt-in, per-project** fallback for `/knowledge-vault:enrich-references`. It is only invoked when the user explicitly asks — never auto-run.

### 1. Preflight

- Require `.vault/` in the current directory. If missing, stop and tell the user: `Run /knowledge-vault:init first.`
- If `.vault/.scihub-enabled` already exists AND an `mcp__scihub__*` tool is visible in this session, report: `Sci-Hub fallback is already enabled for this vault.` and stop.

### 2. Legal disclaimer — require explicit consent

Print the following **verbatim**, then ask: `Type 'yes' to continue, anything else to cancel.`

> ⚠️  **Sci-Hub fallback — read before enabling**
>
> Sci-Hub provides access to research papers by routing around publisher paywalls.
> Its legal status varies by jurisdiction; some countries and institutions block
> access. By enabling this integration you acknowledge:
>
> 1. You are responsible for complying with copyright law in your jurisdiction.
> 2. This plugin neither hosts nor mirrors Sci-Hub content — it only configures a
>    third-party community MCP server (riichard/Sci-Hub-MCP-Server) on your
>    machine.
> 3. The Sci-Hub MCP is enabled **only for this project** (`.vault/.scihub-enabled`
>    marker). To enable it elsewhere, run this command in each project.
> 4. You can disable it anytime by deleting `.vault/.scihub-enabled` and running
>    `claude mcp remove scihub` from this directory.

If the user does not reply exactly `yes` (case-insensitive), print `Cancelled. No changes made.` and stop.

### 3. Check prerequisites

- Check `uv` is available: `command -v uv`. If missing, print:
  > Install `uv` first: `curl -LsSf https://astral.sh/uv/install.sh | sh`
  > Then re-run `/knowledge-vault:setup-scihub`.
  and stop.
- Check `claude` CLI is available: `command -v claude`. If missing, print `Claude Code CLI not found on PATH.` and stop.

### 4. Install the MCP server

Print the command, then run it (user will see a permission prompt):

```bash
uv tool install "sci-hub-mcp-server @ git+https://github.com/riichard/Sci-Hub-MCP-Server"
```

If the install fails, surface the error and stop. Do not proceed to registration.

### 5. Register at project scope

Print the command, then run it (another permission prompt):

```bash
claude mcp add scihub -s project -- sci-hub-mcp --transport stdio
```

This writes a `scihub` entry into this project's `.mcp.json`. User-scope and global-scope registrations are explicitly avoided so Sci-Hub is never enabled across all projects by default.

### 6. Write the per-vault marker

```bash
cat > .vault/.scihub-enabled <<'EOF'
{
  "enabled_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "mcp_source": "github.com/riichard/Sci-Hub-MCP-Server",
  "disclaimer_acknowledged": true
}
EOF
```

(Use a heredoc via `bash -c` so the date is expanded at run time.)

### 7. Smoke test (optional but recommended)

If the user wants, verify the install by running:

```bash
sci-hub-mcp --help 2>&1 | head -5
```

A `--help` output (even if truncated) confirms the binary installed. Skip this if the user declines.

### 8. Tell the user what's next

Print:

> ✓ Sci-Hub MCP installed and registered for this project.
> ✓ Per-vault opt-in marker written to `.vault/.scihub-enabled`.
>
> **Restart Claude Code** so the new MCP tools are picked up, then re-run
> `/knowledge-vault:enrich-references`. Items that Unpaywall couldn't find will
> now fall through to the Sci-Hub fallback.
>
> To disable later: `rm .vault/.scihub-enabled && claude mcp remove scihub` (run
> from this project directory).

## Notes

- **Per-project only**: the `-s project` scope ensures the MCP registration lives in this vault's `.mcp.json`, not in user-global config. Running this in another project requires explicit re-enablement.
- **Non-destructive**: the command refuses to proceed if the marker already exists. Re-running is safe but redundant.
- **No shell-rc edits**: unlike an env-var gate, this command does not modify `~/.bashrc` or `~/.zshrc`. The opt-in is purely a file inside `.vault/`.
- **Credit**: the MCP server is maintained by [riichard](https://github.com/riichard/Sci-Hub-MCP-Server) (a community fork of JackKuo666's original). This plugin only calls its tools — it does not bundle or distribute any Sci-Hub code.
