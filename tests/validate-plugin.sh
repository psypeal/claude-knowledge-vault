#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PLUGIN="$ROOT/plugins/knowledge-vault"

python3 -m py_compile "$PLUGIN"/scripts/*.py
python3 "$ROOT/tests/test_kv.py"

find "$PLUGIN/scripts" -type f -name '*.sh' -print | sort | while IFS= read -r script; do
    sh -n "$script"
done

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

legacy_project="$tmp_dir/legacy project's vault"
mkdir -p "$legacy_project"
"$PLUGIN/scripts/init.sh" "$legacy_project" >/dev/null
(
    cd "$legacy_project"
    "$PLUGIN/scripts/ingest.sh" test-2026-source 'A "quoted" source' notes 'tag one' 'tag"two' >/dev/null
    "$PLUGIN/scripts/index-append.sh" test-2026-source notes >/dev/null
    "$PLUGIN/scripts/ingest-zotero.sh" zotero-2026-source 'A Zotero "source"' ZKEY CITE '10.1000/test' 2026 'Doe, Jane|Smith, John' report false zotero-tag >/dev/null
    python3 - <<'PY'
import json
from pathlib import Path

manifest = json.loads(Path('.vault/raw/.manifest.json').read_text())
source = next(item for item in manifest['sources'] if item['slug'] == 'test-2026-source')
assert source['title'] == 'A "quoted" source'
assert source['tags'] == ['tag one', 'tag"two']
zotero = Path('.vault/raw/zotero-2026-source.md').read_text()
assert 'type: "report"' in zotero
assert 'has_fulltext: false' in zotero
index = Path('.vault/wiki/index.md').read_text()
assert index.count('- `test-2026-source` (notes)') == 1
PY
)

if command -v codex >/dev/null 2>&1; then
    codex_home="$tmp_dir/codex-home"
    plugin_version=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$PLUGIN/.codex-plugin/plugin.json")
    mkdir -p "$codex_home"
    CODEX_HOME="$codex_home" codex plugin marketplace add "$ROOT" --json >/dev/null
    install_json=$(CODEX_HOME="$codex_home" codex plugin add knowledge-vault@knowledge-vault --json)
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

echo "plugin-validation-ok"
