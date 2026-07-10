#!/usr/bin/env python3
"""Install the reviewed PageIndex revision in an isolated environment."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


REVISION = "f413c66fee0bfbb7291c389333f9cc1adac68d57"
DATA_ROOT = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "knowledge-vault"
PAGEINDEX_DIR = DATA_ROOT / f"pageindex-{REVISION[:8]}"
VENV_DIR = DATA_ROOT / f"pageindex-venv-{REVISION[:8]}"


def run(*command: str, cwd: Path | None = None) -> None:
    subprocess.run(command, cwd=cwd, check=True)


def main() -> None:
    if not shutil.which("git"):
        raise SystemExit("git is required")
    DATA_ROOT.mkdir(parents=True, exist_ok=True)
    if not (PAGEINDEX_DIR / ".git").is_dir():
        if PAGEINDEX_DIR.exists():
            raise SystemExit(f"Install path exists but is not a PageIndex checkout: {PAGEINDEX_DIR}")
        with tempfile.TemporaryDirectory(prefix=".pageindex-install.", dir=DATA_ROOT) as temporary:
            checkout = Path(temporary) / "PageIndex"
            run("git", "clone", "--filter=blob:none", "https://github.com/VectifyAI/PageIndex.git", str(checkout))
            run("git", "checkout", "--detach", REVISION, cwd=checkout)
            os.replace(checkout, PAGEINDEX_DIR)
    current = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=PAGEINDEX_DIR, text=True).strip()
    if current != REVISION:
        raise SystemExit(f"Unexpected PageIndex revision at {PAGEINDEX_DIR}: {current}")
    python = VENV_DIR / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
    if not python.is_file():
        run(sys.executable, "-m", "venv", str(VENV_DIR))
    run(str(python), "-m", "pip", "install", "--upgrade", "-r", str(PAGEINDEX_DIR / "requirements.txt"))
    run(str(python), str(PAGEINDEX_DIR / "run_pageindex.py"), "--help")
    print(f"PageIndex ready at {PAGEINDEX_DIR}")
    print(f"Python environment: {VENV_DIR}")


if __name__ == "__main__":
    main()
