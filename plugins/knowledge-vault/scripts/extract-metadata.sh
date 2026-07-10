#!/bin/bash
# knowledge-vault: Emit first-page text of a PDF for metadata extraction by the caller.
#   The host workflow reads stdout and infers authors/org + year + title-keyword
#   to feed into derive-slug.sh.
# Usage: bash extract-metadata.sh <pdf_path> [pages]
#   pages: number of leading pages to extract (default: 1)

set -euo pipefail

PDF_PATH="${1:?Usage: extract-metadata.sh <pdf_path> [pages]}"
PAGES="${2:-1}"

if [ ! -f "$PDF_PATH" ]; then
    echo "PDF not found: $PDF_PATH" >&2
    exit 1
fi

if ! command -v pdftotext >/dev/null 2>&1; then
    echo "pdftotext not found. Install poppler-utils (e.g. apt install poppler-utils)." >&2
    exit 2
fi

# -l N = last page; -layout preserves a bit of structure on title pages.
pdftotext -layout -l "$PAGES" "$PDF_PATH" -
