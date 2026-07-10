#!/bin/bash
# Backward-compatible argv adapter for kv.py's structured ingest request.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SLUG="${1:?Usage: ingest-zotero.sh <slug> <title> <zotero_key> <citekey> <doi> <year> <authors_csv> [type] [has_fulltext] [tags...]}"
TITLE="${2:?Missing title}"
ZOTERO_KEY="${3:?Missing zotero_key}"
CITEKEY="${4:-}"
DOI="${5:-}"
YEAR="${6:-}"
AUTHORS="${7:-}"
TYPE="${8:-paper}"
HAS_FULLTEXT="${9:-false}"
if [ "$#" -ge 9 ]; then shift 9; else shift "$#"; fi
REQUEST="$(mktemp)"
trap 'rm -f "$REQUEST"' EXIT
python3 - "$REQUEST" "$SLUG" "$TITLE" "$ZOTERO_KEY" "$CITEKEY" "$DOI" "$YEAR" "$AUTHORS" "$TYPE" "$HAS_FULLTEXT" "$@" <<'PY'
import json
import sys

(path, slug, title, zotero_key, citekey, doi, year, authors, source_type, has_fulltext, *tags) = sys.argv[1:]
if has_fulltext not in {"true", "false"}:
    raise SystemExit("has_fulltext must be true or false")
frontmatter = {
    "has_fulltext": has_fulltext == "true",
    "zotero_key": zotero_key,
    "authors": [item.strip() for item in authors.split("|") if item.strip()],
}
if citekey:
    frontmatter["citekey"] = citekey
if doi:
    frontmatter["doi"] = doi
if year:
    frontmatter["year"] = year
source = f"https://doi.org/{doi}" if doi else f"zotero://select/library/items/{zotero_key}"
with open(path, "w", encoding="utf-8") as handle:
    json.dump(
        {
            "slug": slug,
            "title": title,
            "type": source_type,
            "source": source,
            "tags": tags,
            "body": "",
            "frontmatter": frontmatter,
            "manifest": {"zotero_key": zotero_key},
            "on_conflict": "suffix",
        },
        handle,
        ensure_ascii=False,
    )
PY
python3 "$SCRIPT_DIR/kv.py" ingest --request "$REQUEST"
