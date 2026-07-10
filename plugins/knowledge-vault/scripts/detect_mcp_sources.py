#!/usr/bin/env python3
"""Detect research integrations without returning credentials."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
from pathlib import Path
from typing import Any


RESEARCH_TERMS = (
    "arxiv",
    "pubmed",
    "scholar",
    "consensus",
    "paper-search",
    "paper_search",
    "zotero",
    "scihub",
    "sci-hub",
)
PAGEINDEX_REVISION = "f413c66fee0bfbb7291c389333f9cc1adac68d57"
DATA_ROOT = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "knowledge-vault"
PAGEINDEX_DIR = Path(
    os.environ.get(
        "KNOWLEDGE_VAULT_PAGEINDEX_DIR",
        DATA_ROOT / f"pageindex-{PAGEINDEX_REVISION[:8]}",
    )
)
detected: dict[str, dict[str, Any]] = {}
available: list[dict[str, Any]] = []


def relevant(name: str) -> bool:
    return any(term in name.lower() for term in RESEARCH_TERMS)


def add_detected(source_id: str, name: str, source_type: str, host: str, tools: list[str] | None = None) -> None:
    entry = detected.setdefault(
        source_id,
        {
            "id": source_id,
            "name": name,
            "type": source_type,
            "enabled": True,
            "hosts": [],
            "tools": tools or [f"mcp__{source_id}__*"],
            "add_commands": None,
        },
    )
    if host not in entry["hosts"]:
        entry["hosts"].append(host)


def read_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def scan_mcp_servers(value: Any, host: str) -> None:
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


settings = read_json(Path.home() / ".claude/settings.json") or {}
allowed = settings.get("permissions", {}).get("allow", [])
pubmed_tools = [str(item) for item in allowed if "PubMed" in str(item)]
scholar_tools = [str(item) for item in allowed if "scholar" in str(item).lower()]
if pubmed_tools:
    add_detected("pubmed-builtin", "PubMed (hosted)", "builtin", "claude", pubmed_tools)
if scholar_tools:
    add_detected("scholar-gateway", "Scholar Gateway (hosted)", "builtin", "claude", scholar_tools)

for candidate in (Path(".mcp.json"), Path(".claude.json"), Path.home() / ".claude.json"):
    payload = read_json(candidate)
    if payload is not None:
        scan_mcp_servers(payload, "claude")

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
            for item in json.loads(result.stdout):
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


def pageindex_status() -> dict[str, bool] | None:
    if not (PAGEINDEX_DIR / "run_pageindex.py").is_file():
        return None
    venv = DATA_ROOT / f"pageindex-venv-{PAGEINDEX_REVISION[:8]}"
    venv_python = venv / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
    candidates = [
        os.environ.get("KNOWLEDGE_VAULT_PYTHON"),
        str(venv_python),
        shutil.which("python3"),
        shutil.which("python"),
    ]
    python = next((item for item in candidates if item and Path(item).exists()), None)
    dependencies = False
    if python:
        try:
            probe = subprocess.run(
                [python, "-c", "import litellm, pymupdf, dotenv, yaml"],
                capture_output=True,
                timeout=10,
                check=False,
            )
            dependencies = probe.returncode == 0
        except (OSError, subprocess.SubprocessError):
            pass
    model = os.environ.get("KNOWLEDGE_VAULT_PAGEINDEX_MODEL", "")
    if model.startswith("openai/"):
        credential = bool(os.environ.get("OPENAI_API_KEY"))
    elif model.startswith("anthropic/"):
        credential = bool(os.environ.get("ANTHROPIC_API_KEY"))
    elif model:
        credential = True
    else:
        credential = bool(os.environ.get("OPENAI_API_KEY") or os.environ.get("ANTHROPIC_API_KEY"))
    return {"python": bool(python), "deps": dependencies, "credential": credential}


pageindex = pageindex_status()
if pageindex and all(pageindex.values()):
    add_detected(
        "pageindex",
        "PageIndex (PDF tree indexing)",
        "local-python",
        "environment",
        ["Local helper used during PDF ingestion"],
    )
else:
    missing = [key for key, present in (pageindex or {}).items() if not present]
    available.append(
        {
            "id": "pageindex",
            "name": "PageIndex (PDF tree indexing)",
            "type": "local-python",
            "note": f"Optional; missing: {', '.join(missing)}" if missing else "Optional; not installed",
            "add_commands": None,
        }
    )

recommended = [
    {
        "id": "consensus",
        "name": "Consensus",
        "type": "http",
        "note": "Academic evidence search with OAuth",
        "add_commands": {
            "claude": "claude mcp add --transport http consensus https://mcp.consensus.app/mcp",
            "codex": [
                "codex mcp add consensus --url https://mcp.consensus.app/mcp",
                "codex mcp login consensus",
            ],
        },
    },
    {
        "id": "arxiv-mcp-server",
        "name": "arXiv",
        "type": "stdio",
        "note": "Search and download arXiv papers",
        "add_commands": {
            "claude": "claude mcp add arxiv-mcp-server -- uvx arxiv-mcp-server==0.5.0 --storage-path .vault/raw/arxiv-papers",
            "codex": "codex mcp add arxiv-mcp-server -- uvx arxiv-mcp-server==0.5.0 --storage-path .vault/raw/arxiv-papers",
        },
    },
    {
        "id": "paper-search",
        "name": "Paper Search",
        "type": "stdio",
        "note": "Search multiple academic indexes",
        "add_commands": {
            "claude": "claude mcp add paper-search -- npx -y paper-search-mcp-nodejs@0.2.7",
            "codex": "codex mcp add paper-search -- npx -y paper-search-mcp-nodejs@0.2.7",
        },
    },
    {
        "id": "zotero",
        "name": "Zotero",
        "type": "stdio",
        "note": "Import local Zotero collections, metadata, and annotations",
        "add_commands": {
            "claude": [
                "uv tool install zotero-mcp-server==0.6.1",
                "zotero-mcp setup",
                "claude mcp add zotero -- zotero-mcp",
            ],
            "codex": [
                "uv tool install zotero-mcp-server==0.6.1",
                "zotero-mcp setup --no-claude",
                "codex mcp add zotero --env ZOTERO_LOCAL=true -- zotero-mcp",
            ],
        },
    },
    {
        "id": "unpaywall",
        "name": "Unpaywall",
        "type": "env-api",
        "note": "Find open-access PDFs by DOI",
        "add_commands": {"all": "Set UNPAYWALL_EMAIL in the user environment"},
    },
]

detected_ids = set(detected)
for source in recommended:
    if source["id"] not in detected_ids and not any(
        source["id"] in source_id or source_id in source["id"] for source_id in detected_ids
    ):
        available.append(source)
for entry in detected.values():
    entry["hosts"].sort()

print(
    json.dumps(
        {
            "detected": sorted(detected.values(), key=lambda item: item["name"].lower()),
            "available": sorted(available, key=lambda item: item["name"].lower()),
        },
        indent=2,
    )
)
