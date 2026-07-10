#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN="$ROOT/plugins/knowledge-vault"

python3 - "$ROOT" "$PLUGIN" <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
plugin = Path(sys.argv[2])

codex_manifest = json.loads((plugin / ".codex-plugin/plugin.json").read_text())
claude_manifest = json.loads((plugin / ".claude-plugin/plugin.json").read_text())
codex_marketplace = json.loads((root / ".agents/plugins/marketplace.json").read_text())
claude_marketplace = json.loads((root / ".claude-plugin/marketplace.json").read_text())

versions = {
    codex_manifest["version"],
    claude_manifest["version"],
    claude_marketplace["metadata"]["version"],
    claude_marketplace["plugins"][0]["version"],
}
assert len(versions) == 1, f"version mismatch: {sorted(versions)}"
assert codex_manifest["name"] == claude_manifest["name"] == "knowledge-vault"
assert codex_marketplace["name"] == claude_marketplace["name"] == "knowledge-vault"
assert not (plugin / ".claude-plugin/marketplace.json").exists(), "nested marketplace manifest is ambiguous"

required_interface = {
    "displayName",
    "shortDescription",
    "longDescription",
    "developerName",
    "category",
    "capabilities",
    "websiteURL",
    "privacyPolicyURL",
    "termsOfServiceURL",
    "defaultPrompt",
}
missing = required_interface - codex_manifest["interface"].keys()
assert not missing, f"Codex interface fields missing: {sorted(missing)}"

skill_names = set()
for skill_file in sorted((plugin / "skills").glob("*/SKILL.md")):
    text = skill_file.read_text()
    match = re.match(r"---\n(.*?)\n---", text, re.S)
    assert match, f"frontmatter missing: {skill_file}"
    frontmatter = match.group(1)
    name_match = re.search(r"^name:\s*(.+)$", frontmatter, re.M)
    description_match = re.search(r"^description:\s*(.+)$", frontmatter, re.M)
    assert name_match and description_match, f"name/description missing: {skill_file}"
    name = name_match.group(1).strip()
    description = description_match.group(1).strip()
    assert skill_file.parent.name == name, f"skill directory/name mismatch: {skill_file.parent.name} != {name}"
    assert description.lower().startswith("use when "), f"weak trigger description: {skill_file}"
    assert name not in skill_names, f"duplicate skill name: {name}"
    skill_names.add(name)

commands = {
    "init",
    "ingest",
    "ingest-zotero",
    "enrich-references",
    "collect",
    "compile",
    "query",
    "process",
    "lint",
    "cleanup",
    "setup-sources",
    "status",
    "agent-reset",
}
for name in commands:
    command = plugin / "commands" / f"{name}.md"
    workflow = plugin / "skills" / "knowledge-vault" / "references" / "workflows" / f"{name}.md"
    assert command.exists(), f"Claude command missing: {name}"
    assert workflow.exists(), f"shared workflow missing: {name}"
    if name not in {"status", "agent-reset"}:
        relative_workflow = f"skills/knowledge-vault/references/workflows/{name}.md"
        assert relative_workflow in command.read_text(), f"command does not route to workflow: {name}"

workflow_root = plugin / "skills" / "knowledge-vault" / "references" / "workflows"
assert "/scripts/ingest.sh" in (workflow_root / "process.md").read_text()
assert "<has_fulltext>" in (workflow_root / "ingest-zotero.md").read_text()
assert "command -v pdftotext" in (workflow_root / "query.md").read_text()
assert "EVERY recovery method" in (workflow_root / "cleanup.md").read_text() or "every recovered file" in (workflow_root / "cleanup.md").read_text()

print(f"manifests-ok version={versions.pop()} skills={len(skill_names)} commands={len(commands)}")
PY

while IFS= read -r script; do
    bash -n "$script"
done < <(find "$PLUGIN/scripts" "$PLUGIN/hooks" -type f -name '*.sh' | sort)

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
project="$tmp_dir/project's vault"
mkdir -p "$project"

bash "$PLUGIN/scripts/init.sh" "$project" >/dev/null
bash "$PLUGIN/scripts/init.sh" "$project" >/dev/null

test -d "$project/.vault/inbox"
test -d "$project/.vault/originals"
test -f "$project/CLAUDE.md"
test -f "$project/AGENTS.md"
test "$(grep -c '^## Knowledge Vault$' "$project/CLAUDE.md")" -eq 1
test "$(grep -c '^## Knowledge Vault$' "$project/AGENTS.md")" -eq 1

(
    cd "$project"
    bash "$PLUGIN/scripts/vault-status.sh" >/dev/null
    detection="$(bash "$PLUGIN/scripts/detect-mcp-sources.sh")"
    printf '%s' "$detection" | python3 -m json.tool >/dev/null
    ! printf '%s' "$detection" | grep -Eq 'Authorization|Bearer |http_headers|api[_-]?key'

    bash "$PLUGIN/scripts/ingest.sh" test-2026-source 'A "quoted" source' notes 'tag one' 'tag"two' >/dev/null
    bash "$PLUGIN/scripts/update-frontmatter.sh" .vault/raw/test-2026-source.md has_tree=false original_path=originals/test-2026-source.pdf >/dev/null
    bash "$PLUGIN/scripts/index-append.sh" test-2026-source notes >/dev/null
    bash "$PLUGIN/scripts/ingest-zotero.sh" zotero-2026-source 'A Zotero "source"' ZKEY CITE '10.1000/test' 2026 'Doe, Jane|Smith, John' report false zotero-tag >/dev/null

    python3 - <<'PY'
import json
from pathlib import Path

manifest = json.loads(Path('.vault/raw/.manifest.json').read_text())
source = next(item for item in manifest['sources'] if item['slug'] == 'test-2026-source')
assert source['title'] == 'A "quoted" source'
assert source['tags'] == ['tag one', 'tag"two']

raw = Path('.vault/raw/test-2026-source.md').read_text()
assert 'has_tree: false' in raw
assert 'original_path: originals/test-2026-source.pdf' in raw

index = Path('.vault/wiki/index.md').read_text()
assert '- `test-2026-source` (notes)' in index

zotero = Path('.vault/raw/zotero-2026-source.md').read_text()
assert 'type: report' in zotero
assert 'has_fulltext: false' in zotero
PY

    printf '{invalid json' > invalid-tree.json
    if bash "$PLUGIN/scripts/render-tree-outline.sh" invalid-tree.json >/dev/null 2>&1; then
        echo "invalid tree JSON unexpectedly passed" >&2
        exit 1
    fi
)

corrupt_project="$tmp_dir/corrupt-project"
mkdir -p "$corrupt_project"
bash "$PLUGIN/scripts/init.sh" "$corrupt_project" >/dev/null
printf '{invalid json' > "$corrupt_project/.vault/raw/.manifest.json"
if (cd "$corrupt_project" && bash "$PLUGIN/scripts/ingest.sh" orphan source notes >/dev/null 2>&1); then
    echo "ingest unexpectedly accepted a corrupt manifest" >&2
    exit 1
fi
test ! -e "$corrupt_project/.vault/raw/orphan.md"

if command -v codex >/dev/null 2>&1; then
    codex_home="$tmp_dir/codex-home"
    plugin_version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$PLUGIN/.codex-plugin/plugin.json")"
    mkdir -p "$codex_home"
    CODEX_HOME="$codex_home" codex plugin marketplace add "$ROOT" --json >/dev/null
    install_json="$(CODEX_HOME="$codex_home" codex plugin add knowledge-vault@knowledge-vault --json)"
    printf '%s' "$install_json" | python3 -c '
import json, sys
result = json.load(sys.stdin)
assert result["name"] == "knowledge-vault"
assert result["version"] == sys.argv[1]
' "$plugin_version"
    test -f "$codex_home/plugins/cache/knowledge-vault/knowledge-vault/$plugin_version/skills/knowledge-vault/SKILL.md"
    echo "codex-install-ok"
fi

if command -v claude >/dev/null 2>&1; then
    claude plugin validate --strict "$ROOT" >/dev/null
    claude plugin validate --strict "$PLUGIN" >/dev/null
    echo "claude-manifest-ok"
fi

echo "shell-and-runtime-ok"
