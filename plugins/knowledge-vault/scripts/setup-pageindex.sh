#!/bin/bash
# Install a pinned PageIndex checkout and isolated Python environment.

set -euo pipefail

PAGEINDEX_REVISION="f413c66fee0bfbb7291c389333f9cc1adac68d57"
DATA_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/knowledge-vault"
PAGEINDEX_DIR="$DATA_ROOT/pageindex-${PAGEINDEX_REVISION:0:8}"
VENV_DIR="$DATA_ROOT/pageindex-venv-${PAGEINDEX_REVISION:0:8}"

command -v git >/dev/null || { echo "git is required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 1; }

mkdir -p "$DATA_ROOT"

if [ ! -d "$PAGEINDEX_DIR/.git" ]; then
    if [ -e "$PAGEINDEX_DIR" ]; then
        echo "Install path exists but is not a PageIndex checkout: $PAGEINDEX_DIR" >&2
        exit 1
    fi
    staging="$(mktemp -d "$DATA_ROOT/.pageindex-install.XXXXXX")"
    trap 'rm -rf "$staging"' EXIT
    git clone --filter=blob:none https://github.com/VectifyAI/PageIndex.git "$staging/PageIndex"
    git -C "$staging/PageIndex" checkout --detach "$PAGEINDEX_REVISION"
    mv "$staging/PageIndex" "$PAGEINDEX_DIR"
    trap - EXIT
    rmdir "$staging"
fi

current_revision="$(git -C "$PAGEINDEX_DIR" rev-parse HEAD)"
if [ "$current_revision" != "$PAGEINDEX_REVISION" ]; then
    echo "Unexpected PageIndex revision at $PAGEINDEX_DIR" >&2
    exit 1
fi

if [ ! -x "$VENV_DIR/bin/python" ]; then
    python3 -m venv "$VENV_DIR"
fi

"$VENV_DIR/bin/pip" install --upgrade -r "$PAGEINDEX_DIR/requirements.txt"
"$VENV_DIR/bin/python" "$PAGEINDEX_DIR/run_pageindex.py" --help >/dev/null

echo "PageIndex ready at $PAGEINDEX_DIR"
echo "Python environment: $VENV_DIR"
