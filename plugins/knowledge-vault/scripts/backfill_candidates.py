#!/usr/bin/env python3
"""List legacy raw sources that are missing preserved originals."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from kv import parse_frontmatter


TARGET_TYPES = {"paper", "article", "report", "manual", "filing", "guideline", "dataset"}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("vault", nargs="?", default=".vault")
    args = parser.parse_args()
    vault = Path(args.vault)
    raw = vault / "raw"
    if not raw.is_dir():
        raise SystemExit("No .vault/raw/ directory found. Initialize the vault first.")

    categorized: dict[str, list[dict[str, str]]] = {
        "from_zotero": [],
        "from_doi": [],
        "from_url": [],
        "unrecoverable": [],
    }
    for path in sorted(raw.glob("*.md")):
        frontmatter, _ = parse_frontmatter(path)
        if not frontmatter or str(frontmatter.get("type", "")).lower() not in TARGET_TYPES:
            continue
        original = str(frontmatter.get("original_path") or "").strip()
        if original and (vault / original).is_file():
            continue
        item = {
            "slug": path.stem,
            "file": str(path),
            "title": str(frontmatter.get("title", "")),
            "year": str(frontmatter.get("year", "")),
            "type": str(frontmatter.get("type", "")),
        }
        zotero_key = str(frontmatter.get("zotero_key") or "").strip()
        doi = str(frontmatter.get("doi") or "").strip()
        source = str(frontmatter.get("source") or "").strip()
        if zotero_key:
            item["zotero_key"] = zotero_key
            categorized["from_zotero"].append(item)
        elif doi:
            item["doi"] = doi
            categorized["from_doi"].append(item)
        elif source.lower().endswith(".pdf") or ".pdf?" in source.lower():
            item["source"] = source
            categorized["from_url"].append(item)
        else:
            item["source"] = source
            categorized["unrecoverable"].append(item)

    result = {
        "categorized": categorized,
        "counts": {key: len(value) for key, value in categorized.items()},
        "total_missing": sum(len(value) for value in categorized.values()),
    }
    print(json.dumps(result, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
