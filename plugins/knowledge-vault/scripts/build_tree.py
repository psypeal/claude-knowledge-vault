#!/usr/bin/env python3
"""Build and validate a PageIndex tree for a preserved PDF."""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


REVISION = "f413c66fee0bfbb7291c389333f9cc1adac68d57"
DATA_ROOT = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "knowledge-vault"
PAGEINDEX_DIR = Path(
    os.environ.get("KNOWLEDGE_VAULT_PAGEINDEX_DIR", DATA_ROOT / f"pageindex-{REVISION[:8]}")
)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("pdf")
    parser.add_argument("slug")
    parser.add_argument("vault")
    args = parser.parse_args()
    pdf = Path(args.pdf).resolve()
    if not pdf.is_file():
        raise SystemExit(f"PDF not found: {pdf}")
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", args.slug):
        raise SystemExit(f"Invalid slug: {args.slug}")
    runner = PAGEINDEX_DIR / "run_pageindex.py"
    if not runner.is_file():
        raise SystemExit("PageIndex is not installed. Run setup-sources first.")
    venv = DATA_ROOT / f"pageindex-venv-{REVISION[:8]}"
    default_python = venv / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
    candidates = [
        os.environ.get("KNOWLEDGE_VAULT_PYTHON"),
        str(default_python),
        shutil.which("python3"),
        shutil.which("python"),
        sys.executable,
    ]
    python = next((item for item in candidates if item and Path(item).is_file()), None)
    if not python:
        raise SystemExit("No Python interpreter is available for PageIndex")
    probe = subprocess.run(
        [python, "-c", "import litellm, pymupdf, PyPDF2, dotenv, yaml"],
        capture_output=True,
        check=False,
    )
    if probe.returncode:
        raise SystemExit("PageIndex dependencies are unavailable. Run setup-sources first.")
    model = os.environ.get("KNOWLEDGE_VAULT_PAGEINDEX_MODEL", "")
    if not model:
        if os.environ.get("OPENAI_API_KEY"):
            model = "openai/gpt-5.4-mini"
        elif os.environ.get("ANTHROPIC_API_KEY"):
            model = "anthropic/claude-sonnet-4-6"
        else:
            raise SystemExit("PageIndex needs a model credential or KNOWLEDGE_VAULT_PAGEINDEX_MODEL")
    if model.startswith("openai/") and not os.environ.get("OPENAI_API_KEY"):
        raise SystemExit(f"OPENAI_API_KEY is required for {model}")
    if model.startswith("anthropic/") and not os.environ.get("ANTHROPIC_API_KEY"):
        raise SystemExit(f"ANTHROPIC_API_KEY is required for {model}")
    target = Path(args.vault) / "raw" / f"{args.slug}.tree.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="knowledge-vault-pageindex-") as temporary:
        work = Path(temporary)
        command = [python, str(runner), "--pdf_path", str(pdf), "--model", model]
        result = subprocess.run(command, cwd=work, check=False)
        if result.returncode:
            raise SystemExit(f"PageIndex failed for {pdf}")
        generated = work / "results" / f"{pdf.stem}_structure.json"
        if not generated.is_file():
            raise SystemExit(f"Expected PageIndex output not found: {generated}")
        try:
            json.loads(generated.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            raise SystemExit(f"PageIndex generated invalid JSON: {error}") from error
        os.replace(generated, target)
    print(f"Tree saved to {target}")


if __name__ == "__main__":
    main()
