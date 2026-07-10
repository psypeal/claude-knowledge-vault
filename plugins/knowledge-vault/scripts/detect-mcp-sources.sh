#!/bin/bash
# Detect configured and available research sources without exposing credentials.

set -euo pipefail

python3 << 'PYEOF'
import json
import os
import shutil
import subprocess

RESEARCH_TERMS = (
    "arxiv", "pubmed", "scholar", "consensus", "paper-search",
    "paper_search", "zotero", "scihub", "sci-hub",
)

detected = {}
available = []
pageindex_revision = "f413c66fee0bfbb7291c389333f9cc1adac68d57"
data_root = os.path.join(
    os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share")),
    "knowledge-vault",
)
pageindex_dir = os.environ.get(
    "KNOWLEDGE_VAULT_PAGEINDEX_DIR",
    os.path.join(data_root, f"pageindex-{pageindex_revision[:8]}"),
)


def relevant(name):
    lowered = name.lower()
    return any(term in lowered for term in RESEARCH_TERMS)


def add_detected(source_id, name, source_type, host, tools=None):
    entry = detected.setdefault(source_id, {
        "id": source_id,
        "name": name,
        "type": source_type,
        "enabled": True,
        "hosts": [],
        "tools": tools or [f"mcp__{source_id}__*"],
        "add_commands": None,
    })
    if host not in entry["hosts"]:
        entry["hosts"].append(host)


def load_json(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, json.JSONDecodeError):
        return None


def scan_mcp_servers(value, host):
    if isinstance(value, dict):
        servers = value.get("mcpServers")
        if isinstance(servers, dict):
            for name, config in servers.items():
                if relevant(name) and not (isinstance(config, dict) and config.get("disabled")):
                    source_type = "http" if isinstance(config, dict) and config.get("url") else "stdio"
                    add_detected(name, name, source_type, host)
        for nested in value.values():
            scan_mcp_servers(nested, host)
    elif isinstance(value, list):
        for nested in value:
            scan_mcp_servers(nested, host)


# Claude Code built-ins and configured project/user MCP servers.
settings = load_json(os.path.expanduser("~/.claude/settings.json")) or {}
allowed = settings.get("permissions", {}).get("allow", [])
pubmed_tools = [item for item in allowed if "PubMed" in str(item)]
scholar_tools = [item for item in allowed if "Scholar" in str(item) or "scholar" in str(item)]
if pubmed_tools:
    add_detected("pubmed-builtin", "PubMed (hosted)", "builtin", "claude", pubmed_tools)
if scholar_tools:
    add_detected("scholar-gateway", "Scholar Gateway (hosted)", "builtin", "claude", scholar_tools)

for path in (
    ".mcp.json",
    ".claude.json",
    os.path.expanduser("~/.claude.json"),
):
    data = load_json(path)
    if data is not None:
        scan_mcp_servers(data, "claude")


# Codex is queried through its CLI because config.toml may contain headers and env references.
# Only server names and transport types are retained; credentials never enter this script's output.
if shutil.which("codex"):
    try:
        result = subprocess.run(
            ["codex", "mcp", "list", "--json"],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
        if result.returncode == 0:
            items = json.loads(result.stdout)
            for item in items:
                name = str(item.get("name", ""))
                if relevant(name) and item.get("enabled", True):
                    transport = item.get("transport") or {}
                    add_detected(name, name, transport.get("type", "mcp"), "codex")
    except (OSError, subprocess.SubprocessError, json.JSONDecodeError, TypeError):
        pass


if os.environ.get("UNPAYWALL_EMAIL"):
    add_detected(
        "unpaywall",
        "Unpaywall",
        "env-api",
        "environment",
        ["HTTP API used by the enrich-references workflow"],
    )


def pageindex_status():
    runner = os.path.join(pageindex_dir, "run_pageindex.py")
    if not os.path.isfile(runner):
        return None

    candidates = [
        os.environ.get("KNOWLEDGE_VAULT_PYTHON"),
        os.path.join(data_root, f"pageindex-venv-{pageindex_revision[:8]}", "bin", "python"),
        shutil.which("python3"),
    ]
    python = next((candidate for candidate in candidates if candidate and os.path.exists(candidate)), None)
    deps = False
    if python:
        try:
            probe = subprocess.run(
                [python, "-c", "import litellm, pymupdf, dotenv, yaml"],
                capture_output=True,
                timeout=10,
                check=False,
            )
            deps = probe.returncode == 0
        except (OSError, subprocess.SubprocessError):
            pass

    model = os.environ.get("KNOWLEDGE_VAULT_PAGEINDEX_MODEL", "")
    if model.startswith("openai/"):
        credential = bool(os.environ.get("OPENAI_API_KEY"))
    elif model.startswith("anthropic/"):
        credential = bool(os.environ.get("ANTHROPIC_API_KEY"))
    elif model:
        credential = True  # Provider-specific credentials are validated by LiteLLM at runtime.
    else:
        credential = bool(os.environ.get("OPENAI_API_KEY") or os.environ.get("ANTHROPIC_API_KEY"))
    return {"python": bool(python), "deps": deps, "credential": credential}


pageindex = pageindex_status()
if pageindex:
    if all(pageindex.values()):
        add_detected(
            "pageindex",
            "PageIndex (PDF tree indexing)",
            "local-python",
            "environment",
            ["Local helper used during PDF ingestion"],
        )
    else:
        missing = [name for name, present in pageindex.items() if not present]
        available.append({
            "id": "pageindex",
            "name": "PageIndex (PDF tree indexing)",
            "type": "local-python",
            "note": f"Optional; missing: {', '.join(missing)}",
            "add_commands": None,
        })
else:
    available.append({
        "id": "pageindex",
        "name": "PageIndex (PDF tree indexing)",
        "type": "local-python",
        "note": "Optional; not installed",
        "add_commands": None,
    })


recommended = [
    {
        "id": "consensus",
        "name": "Consensus",
        "type": "http",
        "note": "Academic evidence search",
        "add_commands": {
            "claude": "claude mcp add --transport http consensus https://mcp.consensus.app/mcp",
            "codex": "codex mcp add consensus --url https://mcp.consensus.app/mcp",
        },
    },
    {
        "id": "arxiv-mcp-server",
        "name": "arXiv",
        "type": "stdio",
        "note": "Search and download arXiv papers",
        "add_commands": {
            "claude": "claude mcp add arxiv-mcp-server -- uvx arxiv-mcp-server --storage-path .vault/raw/arxiv-papers",
            "codex": "codex mcp add arxiv-mcp-server -- uvx arxiv-mcp-server --storage-path .vault/raw/arxiv-papers",
        },
    },
    {
        "id": "paper-search",
        "name": "Paper Search",
        "type": "stdio",
        "note": "Search multiple academic indexes",
        "add_commands": {
            "claude": "claude mcp add paper-search -- npx -y paper-search-mcp-nodejs",
            "codex": "codex mcp add paper-search -- npx -y paper-search-mcp-nodejs",
        },
    },
    {
        "id": "zotero",
        "name": "Zotero",
        "type": "stdio",
        "note": "Import local Zotero collections, metadata, and annotations",
        "add_commands": {
            "claude": "uv tool install zotero-mcp-server && claude mcp add zotero -- zotero-mcp",
            "codex": "uv tool install zotero-mcp-server && codex mcp add zotero --env ZOTERO_LOCAL=true -- zotero-mcp",
        },
    },
    {
        "id": "unpaywall",
        "name": "Unpaywall",
        "type": "env-api",
        "note": "Find open-access PDFs by DOI",
        "add_commands": {
            "all": "export UNPAYWALL_EMAIL=you@example.com",
        },
    },
]

detected_ids = set(detected)
for source in recommended:
    if source["id"] not in detected_ids and not any(
        source["id"] in source_id or source_id in source["id"]
        for source_id in detected_ids
    ):
        available.append(source)

for entry in detected.values():
    entry["hosts"].sort()

print(json.dumps({
    "detected": sorted(detected.values(), key=lambda item: item["name"].lower()),
    "available": sorted(available, key=lambda item: item["name"].lower()),
}, indent=2))
PYEOF
