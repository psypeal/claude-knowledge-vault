#!/bin/sh
# Backward-compatible wrapper. New workflows invoke extract_pdf.py directly.
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PAGES=${2:-1}
exec python3 "$SCRIPT_DIR/extract_pdf.py" "$1" --first 1 --last "$PAGES" --layout
