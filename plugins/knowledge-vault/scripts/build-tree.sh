#!/bin/bash
# knowledge-vault: Build a PageIndex tree for a PDF and save it to <vault>/raw/<slug>.tree.json.
# Usage: bash build-tree.sh <pdf_path> <slug> <vault_dir>
#
# Exit codes:
#   0  success — tree.json written
#   2  PageIndex not set up (vendor missing or python deps missing)
#   3  ANTHROPIC_API_KEY not set
#   4  PDF not found
#   5  PageIndex run failed (caller should fall back to flat condense)

set -euo pipefail

PDF_PATH="${1:?Usage: build-tree.sh <pdf_path> <slug> <vault_dir>}"
SLUG="${2:?Missing slug}"
VAULT_DIR="${3:?Missing vault_dir}"

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PAGEINDEX_DIR="$PLUGIN_DIR/vendor/PageIndex"
RUNNER="$PAGEINDEX_DIR/run_pageindex.py"

if [ ! -f "$RUNNER" ]; then
    echo "PageIndex vendor not found at $PAGEINDEX_DIR" >&2
    exit 2
fi

if ! python3 -c "import litellm, pymupdf, dotenv, yaml, PyPDF2" 2>/dev/null; then
    echo "PageIndex Python dependencies not installed. Run: pip3 install -r $PAGEINDEX_DIR/requirements.txt" >&2
    exit 2
fi

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
    # Permit a fallback to vendor/.env if present (set up by setup-sources)
    if [ -f "$PAGEINDEX_DIR/.env" ]; then
        # shellcheck disable=SC1090
        set -a
        . "$PAGEINDEX_DIR/.env"
        set +a
    fi
    if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
        echo "ANTHROPIC_API_KEY not set; cannot build tree via Claude" >&2
        exit 3
    fi
fi

if [ ! -f "$PDF_PATH" ]; then
    echo "PDF not found: $PDF_PATH" >&2
    exit 4
fi

OUT_DIR="$VAULT_DIR/raw"
TARGET="$OUT_DIR/$SLUG.tree.json"
# Match run_pageindex.py's os.path.splitext: strip the final extension whatever
# its case ("Paper.PDF" -> "Paper"), so we look for the same results filename.
PDF_FILENAME="$(basename "$PDF_PATH")"
PDF_BASENAME="${PDF_FILENAME%.*}"

# PageIndex writes to ./results/<pdfname>_structure.json relative to CWD.
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# PageIndex needs an absolute path since we cd away.
PDF_ABS="$(cd "$(dirname "$PDF_PATH")" && pwd)/$(basename "$PDF_PATH")"

(
    cd "$WORK_DIR"
    python3 "$RUNNER" --pdf_path "$PDF_ABS" 2>&1
) || {
    echo "PageIndex run failed for $PDF_PATH" >&2
    exit 5
}

GENERATED="$WORK_DIR/results/${PDF_BASENAME}_structure.json"
if [ ! -f "$GENERATED" ]; then
    echo "Expected output not found at $GENERATED" >&2
    exit 5
fi

mkdir -p "$OUT_DIR"
mv "$GENERATED" "$TARGET"
echo "Tree saved to $TARGET"
