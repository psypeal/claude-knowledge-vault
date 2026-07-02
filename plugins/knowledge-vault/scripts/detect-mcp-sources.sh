#!/bin/bash
# knowledge-vault: Detect available research MCP servers.
# Checks Claude settings permissions, .claude.json / .mcp.json mcpServers,
# and Codex's ~/.codex/config.toml [mcp_servers] sections.
# Output: JSON listing detected and available-but-not-configured servers.

# Resolve plugin root so we can probe the vendored PageIndex install state.
PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
export PLUGIN_DIR

python3 << 'PYEOF'
import json, os, shutil, subprocess

detected = []
available = []
plugin_dir = os.environ.get('PLUGIN_DIR', '')
pageindex_dir = os.path.join(plugin_dir, 'vendor', 'PageIndex') if plugin_dir else ''

RESEARCH_KEYWORDS = ['arxiv', 'pubmed', 'scholar', 'consensus', 'paper-search', 'zotero', 'scihub', 'sci-hub']


def load_json(path):
    """Read a JSON config file; malformed/unreadable files are skipped, not fatal."""
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError, ValueError):
        return None


def add_detected(entry):
    """Append unless an entry with the same id is already detected."""
    if not any(d['id'] == entry['id'] for d in detected):
        detected.append(entry)


# Check Claude settings.json for allowed MCP tools (built-in AI-hosted research tools)
settings = load_json(os.path.expanduser('~/.claude/settings.json'))
if settings:
    allowed = settings.get('permissions', {}).get('allow', [])

    # PubMed (built-in)
    if any('PubMed' in str(p) for p in allowed):
        add_detected({
            'id': 'pubmed-builtin',
            'name': 'PubMed (AI-hosted)',
            'type': 'builtin',
            'enabled': True,
            'tools': [p for p in allowed if 'PubMed' in str(p)],
            'add_command': None
        })

    # Scholar Gateway (built-in)
    if any('Scholar_Gateway' in str(p) or 'scholar-gateway' in str(p) for p in allowed):
        add_detected({
            'id': 'scholar-gateway',
            'name': 'Scholar Gateway (AI-hosted)',
            'type': 'builtin',
            'enabled': True,
            'tools': [p for p in allowed if 'Scholar' in str(p) or 'scholar' in str(p)],
            'add_command': None
        })

# Check Claude JSON configs for configured MCP servers.
# .mcp.json is where `claude mcp add -s project` writes.
for mcp_json_path in ['.claude.json', os.path.expanduser('~/.claude.json'), '.mcp.json']:
    cj = load_json(mcp_json_path)
    if not cj:
        continue
    servers = cj.get('mcpServers', {})
    for name, config in servers.items():
        if any(kw in name.lower() for kw in RESEARCH_KEYWORDS):
            add_detected({
                'id': name,
                'name': name,
                'type': 'stdio',
                'enabled': True,
                'tools': [f'mcp__{name}__*'],
                'add_command': None
            })

# Check Codex's config.toml for configured MCP servers ([mcp_servers.<name>] sections)
codex_toml = os.path.expanduser('~/.codex/config.toml')
if os.path.isfile(codex_toml):
    try:
        import tomllib
        with open(codex_toml, 'rb') as f:
            codex_cfg = tomllib.load(f)
        for name in codex_cfg.get('mcp_servers', {}):
            if any(kw in name.lower() for kw in RESEARCH_KEYWORDS):
                add_detected({
                    'id': name,
                    'name': f'{name} (Codex)',
                    'type': 'stdio',
                    'enabled': True,
                    'tools': [f'mcp__{name}__*'],
                    'add_command': None
                })
    except Exception:
        pass  # tomllib absent (python < 3.11) or malformed toml — skip

# Check for Unpaywall (not an MCP; just an email env var)
if os.environ.get('UNPAYWALL_EMAIL'):
    add_detected({
        'id': 'unpaywall',
        'name': 'Unpaywall',
        'type': 'env-api',
        'enabled': True,
        'tools': ['(HTTP API; enables /knowledge-vault:enrich-references)'],
        'add_command': None
    })


# Check for PageIndex (bundled python tool; not an MCP)
def _pageindex_env_has_key():
    """True only if vendor/PageIndex/.env contains a non-empty ANTHROPIC_API_KEY."""
    env_path = os.path.join(pageindex_dir, '.env')
    try:
        with open(env_path) as f:
            for line in f:
                line = line.strip()
                if line.startswith('ANTHROPIC_API_KEY='):
                    return bool(line.partition('=')[2].strip().strip('"').strip("'"))
    except OSError:
        pass
    return False


def _pageindex_status():
    if not pageindex_dir or not os.path.isfile(os.path.join(pageindex_dir, 'run_pageindex.py')):
        return None  # not vendored
    has_python = shutil.which('python3') is not None
    has_deps = False
    if has_python:
        try:
            r = subprocess.run(
                ['python3', '-c', 'import litellm, pymupdf, dotenv, yaml, PyPDF2'],
                capture_output=True
            )
            has_deps = (r.returncode == 0)
        except Exception:
            has_deps = False
    has_key = bool(os.environ.get('ANTHROPIC_API_KEY')) or _pageindex_env_has_key()
    return {'python': has_python, 'deps': has_deps, 'key': has_key}


pi = _pageindex_status()
if pi is not None:
    if pi['python'] and pi['deps'] and pi['key']:
        add_detected({
            'id': 'pageindex',
            'name': 'PageIndex (tree indexing)',
            'type': 'bundled-py',
            'enabled': True,
            'tools': ['(local Python; auto-runs on every PDF ingest)'],
            'add_command': None
        })
    else:
        missing = []
        if not pi['python']:
            missing.append('python3')
        if not pi['deps']:
            missing.append('pip deps')
        if not pi['key']:
            missing.append('ANTHROPIC_API_KEY')
        available.append({
            'id': 'pageindex',
            'name': 'PageIndex (tree indexing)',
            'type': 'bundled-py',
            'note': f'Bundled at vendor/PageIndex; missing: {", ".join(missing)}. When set up, every ingested PDF gets a hierarchical tree index for finer-grained query routing.',
            'add_command': 'See /knowledge-vault:setup-sources → PageIndex',
            'api_key': True
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
    },
    {
        'id': 'zotero',
        'name': 'Zotero',
        'type': 'stdio',
        'note': 'Read your local Zotero library — collections, metadata, PDF fulltext, annotations (enables /knowledge-vault:ingest-zotero)',
        'add_command': 'uv tool install zotero-mcp-server && zotero-mcp setup',
        'api_key': False
    },
    {
        'id': 'unpaywall',
        'name': 'Unpaywall',
        'type': 'env-api',
        'note': 'Find open-access PDFs for reference-only items by DOI (enables /knowledge-vault:enrich-references). Free, no signup — just an email for polite API use.',
        'add_command': 'export UNPAYWALL_EMAIL=you@example.com  # add to ~/.bashrc or ~/.zshrc to persist',
        'api_key': False
    }
]

detected_ids = {d['id'] for d in detected}
for server in recommended:
    # Skip if already detected by name match
    if server['id'] not in detected_ids and not any(server['id'] in d.get('id', '') for d in detected):
        available.append(server)

result = {'detected': detected, 'available': available}
print(json.dumps(result, indent=2))
PYEOF
