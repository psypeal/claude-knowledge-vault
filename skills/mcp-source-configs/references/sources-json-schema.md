# sources.json Schema

The `.vault/sources.json` file tracks which research MCP servers are configured for this vault. It is created by `vault init` (empty) and populated by `/vault:setup-sources`.

## Schema

```json
{
  "version": 1,
  "configured_sources": [
    {
      "id": "string — unique server identifier (e.g., 'pubmed-builtin', 'consensus', 'arxiv-mcp-server')",
      "name": "string — human-readable name (e.g., 'PubMed (Claude.ai)')",
      "type": "string — 'builtin' | 'stdio' | 'http'",
      "status": "string — 'active' | 'inactive' | 'error'",
      "added": "string — ISO 8601 UTC timestamp when configured",
      "add_command": "string | null — the claude mcp add command used (null for builtins)",
      "api_key_required": "boolean — whether an API key is needed",
      "notes": "string | null — optional notes (e.g., 'requires uv', 'Node.js needed')"
    }
  ],
  "last_configured": "string | null — ISO 8601 UTC timestamp of last setup-sources run"
}
```

## Example

```json
{
  "version": 1,
  "configured_sources": [
    {
      "id": "pubmed-builtin",
      "name": "PubMed (Claude.ai)",
      "type": "builtin",
      "status": "active",
      "added": "2026-04-03T14:00:00Z",
      "add_command": null,
      "api_key_required": false,
      "notes": null
    },
    {
      "id": "scholar-gateway",
      "name": "Scholar Gateway (Claude.ai)",
      "type": "builtin",
      "status": "active",
      "added": "2026-04-03T14:00:00Z",
      "add_command": null,
      "api_key_required": false,
      "notes": null
    },
    {
      "id": "consensus",
      "name": "Consensus",
      "type": "http",
      "status": "active",
      "added": "2026-04-03T14:05:00Z",
      "add_command": "claude mcp add --transport http consensus https://mcp.consensus.app/mcp",
      "api_key_required": false,
      "notes": null
    },
    {
      "id": "arxiv-mcp-server",
      "name": "arXiv",
      "type": "stdio",
      "status": "active",
      "added": "2026-04-03T14:05:00Z",
      "add_command": "claude mcp add arxiv-mcp-server -- uvx arxiv-mcp-server --storage-path .vault/raw/arxiv-papers",
      "api_key_required": false,
      "notes": "requires uv (Python package manager)"
    }
  ],
  "last_configured": "2026-04-03T14:05:00Z"
}
```

## Empty State

Created by `vault init`:

```json
{
  "version": 1,
  "configured_sources": [],
  "last_configured": null
}
```

## Status Values

| Status | Meaning |
|--------|---------|
| `active` | Server is configured and available for use |
| `inactive` | Server was configured but has been disabled by user |
| `error` | Server configuration exists but the server is not responding or has been removed |

## Usage

- **Read by**: `/vault:collect` (to know which servers to search), `/vault:setup-sources` (to show current state), `detect-mcp-sources.sh` (to compare detected vs configured)
- **Written by**: `/vault:setup-sources` (after user approves server additions)
- **Location**: `.vault/sources.json` (project-scoped, not global)
