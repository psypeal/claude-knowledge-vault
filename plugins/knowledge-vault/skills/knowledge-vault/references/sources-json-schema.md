# `sources.json` schema

Knowledge Vault stores project-specific source preferences in `.vault/sources.json`. The file records what the user configured; runtime tool availability must still be checked before each search.

```json
{
  "version": 1,
  "configured_sources": [
    {
      "id": "consensus",
      "name": "Consensus",
      "type": "http",
      "enabled": true,
      "hosts": ["codex"],
      "tools": ["mcp__consensus__*"],
      "add_commands": {
        "claude": "claude mcp add --transport http consensus https://mcp.consensus.app/mcp",
        "codex": "codex mcp add consensus --url https://mcp.consensus.app/mcp"
      },
      "added": "2026-07-10T12:00:00Z"
    }
  ],
  "last_configured": "2026-07-10T12:00:00Z"
}
```

| Field | Type | Meaning |
|---|---|---|
| `id` | string | Stable source identifier |
| `name` | string | Human-readable name |
| `type` | string | `builtin`, `stdio`, `http`, `env-api`, or `local-python` |
| `enabled` | boolean | User intent to use the source |
| `hosts` | string[] | Hosts where configuration was detected, such as `claude` or `codex` |
| `tools` | string[] | Expected MCP tool names or patterns |
| `add_commands` | object/null | Host-specific setup commands; never include credentials |
| `added` | string | UTC ISO 8601 timestamp |

Rules:

- Preserve unknown fields when updating the file.
- Add a source only after its setup succeeds.
- Never store API keys, authorization headers, cookies, or other credentials.
- Treat `enabled` as preference, not proof that the server is reachable.
- Keep the empty state as `{"version":1,"configured_sources":[],"last_configured":null}`.
