#!/usr/bin/env python3
"""Download an HTTP(S) artifact from a structured request."""

from __future__ import annotations

import argparse
import json
import os
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


MAX_ALLOWED_BYTES = 200 * 1024 * 1024


def load_request(path: Path) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise SystemExit(f"Invalid download request: {error}") from error
    if not isinstance(payload, dict):
        raise SystemExit("Download request must be a JSON object")
    url = payload.get("url")
    output = payload.get("output")
    if not isinstance(url, str) or urllib.parse.urlparse(url).scheme not in {"http", "https"}:
        raise SystemExit("Download URL must use HTTP or HTTPS")
    if not isinstance(output, str) or not output:
        raise SystemExit("Download request requires an output path")
    if payload.get("expected", "file") not in {"file", "pdf"}:
        raise SystemExit("expected must be file or pdf")
    size = payload.get("max_bytes", 100 * 1024 * 1024)
    if not isinstance(size, int) or size < 1 or size > MAX_ALLOWED_BYTES:
        raise SystemExit(f"max_bytes must be between 1 and {MAX_ALLOWED_BYTES}")
    return payload


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--request", required=True)
    args = parser.parse_args()
    request_path = Path(args.request).resolve()
    payload = load_request(request_path)
    output = Path(payload["output"])
    if not output.is_absolute():
        output = (request_path.parent / output).resolve()
    project = Path.cwd().resolve()
    try:
        output.relative_to(project)
    except ValueError as error:
        raise SystemExit(f"Output must stay inside the current project: {output}") from error
    output.parent.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(
        payload["url"],
        headers={"User-Agent": "Knowledge-Vault/2.6 (+https://github.com/psypeal/knowledge-vault)"},
    )
    descriptor, temporary = tempfile.mkstemp(prefix=f".{output.name}.", dir=output.parent)
    os.close(descriptor)
    temp_path = Path(temporary)
    total = 0
    try:
        try:
            with urllib.request.urlopen(request, timeout=60) as response, temp_path.open("wb") as handle:
                final_scheme = urllib.parse.urlparse(response.geturl()).scheme
                if final_scheme not in {"http", "https"}:
                    raise SystemExit(f"Redirected to unsupported URL scheme: {final_scheme}")
                while chunk := response.read(1024 * 1024):
                    total += len(chunk)
                    if total > payload.get("max_bytes", 100 * 1024 * 1024):
                        raise SystemExit("Download exceeded max_bytes")
                    handle.write(chunk)
        except urllib.error.URLError as error:
            raise SystemExit(f"Download failed: {error}") from error
        if payload.get("expected") == "pdf":
            with temp_path.open("rb") as handle:
                if b"%PDF-" not in handle.read(1024):
                    raise SystemExit("Downloaded response is not a PDF")
        os.replace(temp_path, output)
    finally:
        temp_path.unlink(missing_ok=True)
    print(json.dumps({"status": "downloaded", "output": str(output), "bytes": total}))


if __name__ == "__main__":
    main()
