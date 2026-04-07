#!/bin/bash
# knowledge-vault: Detect available research MCP servers.
# Checks settings.json permissions and .claude.json mcpServers.
# Output: JSON listing detected and available-but-not-configured servers.

python3 -c "
import json, os

detected = []
available = []

# Check settings.json for allowed MCP tools (built-in Claude.ai servers)
settings_path = os.path.expanduser('~/.claude/settings.json')
if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)
    allowed = settings.get('permissions', {}).get('allow', [])

    # PubMed (built-in)
    if any('PubMed' in str(p) for p in allowed):
        detected.append({
            'id': 'pubmed-builtin',
            'name': 'PubMed (Claude.ai)',
            'type': 'builtin',
            'enabled': True,
            'tools': [p for p in allowed if 'PubMed' in str(p)],
            'add_command': None
        })

    # Scholar Gateway (built-in)
    if any('Scholar_Gateway' in str(p) or 'scholar-gateway' in str(p) for p in allowed):
        detected.append({
            'id': 'scholar-gateway',
            'name': 'Scholar Gateway (Claude.ai)',
            'type': 'builtin',
            'enabled': True,
            'tools': [p for p in allowed if 'Scholar' in str(p) or 'scholar' in str(p)],
            'add_command': None
        })

# Check .claude.json for locally configured MCP servers
for claude_json_path in ['.claude.json', os.path.expanduser('~/.claude.json')]:
    if os.path.exists(claude_json_path):
        with open(claude_json_path) as f:
            cj = json.load(f)
        servers = cj.get('mcpServers', {})
        for name, config in servers.items():
            if any(kw in name.lower() for kw in ['arxiv', 'pubmed', 'scholar', 'consensus', 'paper-search']):
                detected.append({
                    'id': name,
                    'name': name,
                    'type': 'stdio',
                    'enabled': True,
                    'tools': [f'mcp__{name}__*'],
                    'add_command': None
                })

# Available servers (not yet detected)
recommended = [
    {
        'id': 'consensus',
        'name': 'Consensus',
        'type': 'http',
        'note': 'Academic research consensus engine',
        'add_command': 'claude mcp add --transport http consensus https://mcp.consensus.app/mcp',
        'api_key': False
    },
    {
        'id': 'arxiv-mcp-server',
        'name': 'arXiv',
        'type': 'stdio',
        'note': 'Search and download arXiv papers (2.5k stars)',
        'add_command': 'claude mcp add arxiv-mcp-server -- uvx arxiv-mcp-server --storage-path .vault/raw/arxiv-papers',
        'api_key': False
    },
    {
        'id': 'paper-search',
        'name': 'Paper Search (14 databases)',
        'type': 'stdio',
        'note': 'arXiv, PubMed, Semantic Scholar, bioRxiv, medRxiv, Crossref + more',
        'add_command': 'claude mcp add paper-search -- npx -y paper-search-mcp-nodejs',
        'api_key': False
    }
]

detected_ids = {d['id'] for d in detected}
for server in recommended:
    # Skip if already detected by name match
    if server['id'] not in detected_ids and not any(server['id'] in d.get('id','') for d in detected):
        available.append(server)

result = {'detected': detected, 'available': available}
print(json.dumps(result, indent=2))
"
