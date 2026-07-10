#!/usr/bin/env python3
"""List reference-only raw sources that have a DOI."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from kv import parse_frontmatter


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("vault", nargs="?", default=".vault")
    args = parser.parse_args()
    raw = Path(args.vault) / "raw"
    if not raw.is_dir():
        raise SystemExit("No .vault/raw/ directory found. Initialize the vault first.")
    candidates = []
    for path in sorted(raw.glob("*.md")):
        frontmatter, _ = parse_frontmatter(path)
        doi = str(frontmatter.get("doi") or "").strip()
        if frontmatter.get("has_fulltext") is False and doi:
            candidates.append(
                {
                    "slug": path.stem,
                    "doi": doi,
                    "file": str(path),
                    "title": str(frontmatter.get("title", "")),
                    "year": str(frontmatter.get("year", "")),
                }
            )
    print(json.dumps({"candidates": candidates, "count": len(candidates)}, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
