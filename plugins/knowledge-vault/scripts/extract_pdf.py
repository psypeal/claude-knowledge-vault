#!/usr/bin/env python3
"""Extract a bounded PDF page range with Poppler's pdftotext."""

from __future__ import annotations

import argparse
import shutil
import subprocess
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("pdf")
    parser.add_argument("--first", type=int, default=1)
    parser.add_argument("--last", type=int)
    parser.add_argument("--layout", action="store_true")
    parser.add_argument("--output")
    args = parser.parse_args()
    pdf = Path(args.pdf)
    if not pdf.is_file():
        raise SystemExit(f"PDF not found: {pdf}")
    if args.first < 1 or (args.last is not None and args.last < args.first):
        raise SystemExit("Invalid PDF page range")
    executable = shutil.which("pdftotext")
    if not executable:
        raise SystemExit("pdftotext not found. Install Poppler (poppler-utils on Debian/Ubuntu).")
    command = [executable]
    if args.layout:
        command.append("-layout")
    command.extend(["-f", str(args.first)])
    if args.last is not None:
        command.extend(["-l", str(args.last)])
    output = Path(args.output) if args.output else None
    command.extend([str(pdf), str(output) if output else "-"])
    if output:
        output.parent.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(command, check=False)
    raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
