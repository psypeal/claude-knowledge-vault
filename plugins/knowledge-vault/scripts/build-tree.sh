#!/bin/bash
# knowledge-vault: Build a PageIndex tree for a PDF and save it to <vault>/raw/<slug>.tree.json.
# Usage: bash build-tree.sh <pdf_path> <slug> <vault_dir>
#
# Exit codes:
#   0  success — tree.json written
#   2  PageIndex not installed or dependencies missing
#   3  model credentials not set
#   4  PDF not found
#   5  PageIndex run failed (caller should fall back to flat condense)

set -euo pipefail

PDF_PATH="${1:?Usage: build-tree.sh <pdf_path> <slug> <vault_dir>}"
SLUG="${2:?Missing slug}"
VAULT_DIR="${3:?Missing vault_dir}"

if [ ! -f "$PDF_PATH" ]; then
    echo "PDF not found: $PDF_PATH" >&2
    exit 4
fi

if [[ ! "$SLUG" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
    echo "Invalid slug: $SLUG" >&2
    exit 5
fi

PAGEINDEX_REVISION="f413c66fee0bfbb7291c389333f9cc1adac68d57"
DATA_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/knowledge-vault"
PAGEINDEX_DIR="${KNOWLEDGE_VAULT_PAGEINDEX_DIR:-$DATA_ROOT/pageindex-${PAGEINDEX_REVISION:0:8}}"
RUNNER="$PAGEINDEX_DIR/run_pageindex.py"
DEFAULT_PYTHON="$DATA_ROOT/pageindex-venv-${PAGEINDEX_REVISION:0:8}/bin/python"

if [ -n "${KNOWLEDGE_VAULT_PYTHON:-}" ]; then
    PYTHON="$KNOWLEDGE_VAULT_PYTHON"
elif [ -x "$DEFAULT_PYTHON" ]; then
    PYTHON="$DEFAULT_PYTHON"
else
    PYTHON="$(command -v python3 || true)"
fi

if [ ! -f "$RUNNER" ]; then
    echo "PageIndex is not installed. Run the PageIndex section of setup-sources." >&2
    exit 2
fi

if [ -z "$PYTHON" ] || ! "$PYTHON" -c "import litellm, pymupdf, PyPDF2, dotenv, yaml" 2>/dev/null; then
    echo "PageIndex dependencies are unavailable. Run the PageIndex section of the setup-sources workflow." >&2
    exit 2
fi

MODEL="${KNOWLEDGE_VAULT_PAGEINDEX_MODEL:-}"
if [ -z "$MODEL" ]; then
    if [ -n "${OPENAI_API_KEY:-}" ]; then
        MODEL="openai/gpt-5.4-mini"
    elif [ -n "${ANTHROPIC_API_KEY:-}" ]; then
        MODEL="anthropic/claude-sonnet-4-6"
    else
        echo "PageIndex needs OPENAI_API_KEY, ANTHROPIC_API_KEY, or a configured provider credential." >&2
        exit 3
    fi
elif [[ "$MODEL" == openai/* ]] && [ -z "${OPENAI_API_KEY:-}" ]; then
    echo "OPENAI_API_KEY is required for PageIndex model $MODEL" >&2
    exit 3
elif [[ "$MODEL" == anthropic/* ]] && [ -z "${ANTHROPIC_API_KEY:-}" ]; then
    echo "ANTHROPIC_API_KEY is required for PageIndex model $MODEL" >&2
    exit 3
fi

OUT_DIR="$VAULT_DIR/raw"
TARGET="$OUT_DIR/$SLUG.tree.json"
PDF_BASENAME="$(basename "$PDF_PATH")"
PDF_BASENAME="${PDF_BASENAME%.*}"

# PageIndex writes to ./results/<pdfname>_structure.json relative to CWD.
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# PageIndex needs an absolute path since we cd away.
PDF_ABS="$(cd "$(dirname "$PDF_PATH")" && pwd)/$(basename "$PDF_PATH")"

(
    cd "$WORK_DIR"
    ARGS=(--pdf_path "$PDF_ABS")
    [ -n "$MODEL" ] && ARGS+=(--model "$MODEL")
    "$PYTHON" "$RUNNER" "${ARGS[@]}" 2>&1
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
