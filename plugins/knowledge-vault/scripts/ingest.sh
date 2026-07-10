#!/bin/bash
# Backward-compatible argv adapter for kv.py's structured ingest request.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SLUG="${1:?Usage: ingest.sh <slug> <title> <type> [tags...]}"
TITLE="${2:?Missing title}"
TYPE="${3:?Missing type}"
shift 3
REQUEST="$(mktemp)"
trap 'rm -f "$REQUEST"' EXIT
python3 - "$REQUEST" "$SLUG" "$TITLE" "$TYPE" "$@" <<'PY'
import json
import sys

path, slug, title, source_type, *tags = sys.argv[1:]
with open(path, "w", encoding="utf-8") as handle:
    json.dump(
        {"slug": slug, "title": title, "type": source_type, "tags": tags, "body": ""},
        handle,
        ensure_ascii=False,
    )
PY
python3 "$SCRIPT_DIR/kv.py" ingest --request "$REQUEST"
