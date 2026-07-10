#!/usr/bin/env python3
"""Cross-platform state and integrity CLI for Knowledge Vault."""

from __future__ import annotations

import argparse
import html
import json
import os
import re
import shutil
import sys
import tempfile
import time
import unicodedata
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterator
from urllib.parse import quote


SOURCE_TYPES = {
    "article",
    "clip",
    "dataset",
    "filing",
    "guideline",
    "manual",
    "meeting",
    "notes",
    "paper",
    "repo",
    "report",
}
INGEST_FRONTMATTER_RESERVED = {
    "compiled",
    "ingested",
    "original_filename",
    "original_path",
    "source",
    "tags",
    "title",
    "type",
}
INGEST_MANIFEST_RESERVED = {"compiled", "file", "ingested", "slug", "tags", "title", "type"}
KEY_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_-]*\Z")
SLUG_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*\Z")
WIKILINK_RE = re.compile(r"\[\[([^\]]+)\]\]")
VAULT_DIRECTORIES = (
    "Clippings",
    "inbox",
    "originals",
    "raw",
    "templates",
    "wiki/concepts",
    "wiki/summaries",
    "wiki/outputs",
)
PRIVATE_GITIGNORE = "*\n!.gitignore\n"


class VaultError(RuntimeError):
    pass


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise VaultError(f"Required file not found: {path}") from error
    except json.JSONDecodeError as error:
        raise VaultError(f"Invalid JSON in {path}: {error}") from error


def validate_manifest_data(payload: Any, path: Path) -> dict[str, Any]:
    if not isinstance(payload, dict) or not isinstance(payload.get("sources"), list):
        raise VaultError(f"Manifest has an invalid structure: {path}")
    seen: set[str] = set()
    for index, item in enumerate(payload["sources"]):
        if not isinstance(item, dict):
            raise VaultError(f"Manifest source {index} must be an object: {path}")
        slug = item.get("slug")
        if not isinstance(slug, str) or not SLUG_RE.fullmatch(slug):
            raise VaultError(f"Manifest source {index} has an invalid slug {slug!r}: {path}")
        if slug in seen:
            raise VaultError(f"Manifest has duplicate slug {slug!r}: {path}")
        seen.add(slug)
        if item.get("file", f"{slug}.md") != f"{slug}.md":
            raise VaultError(f"Manifest source {slug} has an inconsistent file path: {path}")
        if not isinstance(item.get("title"), str):
            raise VaultError(f"Manifest source {slug} has an invalid title: {path}")
        if item.get("type") not in SOURCE_TYPES:
            raise VaultError(f"Manifest source {slug} has an invalid type: {path}")
        if not isinstance(item.get("compiled"), bool):
            raise VaultError(f"Manifest source {slug} has a non-boolean compiled state: {path}")
    return payload


def load_manifest(path: Path) -> dict[str, Any]:
    return validate_manifest_data(load_json(path), path)


def atomic_write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent, text=True)
    temp_path = Path(temporary)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp_path, path)
    finally:
        temp_path.unlink(missing_ok=True)


def atomic_write_json(path: Path, payload: Any) -> None:
    atomic_write_text(path, json.dumps(payload, indent=2, ensure_ascii=False) + "\n")


@contextmanager
def vault_lock(vault: Path, timeout: float = 15.0) -> Iterator[None]:
    lock = vault / ".knowledge-vault.lock"
    deadline = time.monotonic() + timeout
    while True:
        try:
            descriptor = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
            with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
                handle.write(json.dumps({"pid": os.getpid(), "created": utc_now()}))
            break
        except FileExistsError:
            try:
                stale = time.time() - lock.stat().st_mtime > 300
            except FileNotFoundError:
                continue
            if stale:
                lock.unlink(missing_ok=True)
                continue
            if time.monotonic() >= deadline:
                raise VaultError(f"Timed out waiting for vault lock: {lock}")
            time.sleep(0.1)
    try:
        yield
    finally:
        lock.unlink(missing_ok=True)


def require_vault(value: str | Path = ".vault") -> Path:
    vault = Path(value)
    if not vault.is_dir():
        raise VaultError(f"No vault found at {vault}. Initialize it first.")
    return vault


@contextmanager
def path_lock(path: Path) -> Iterator[None]:
    resolved = path.resolve()
    vault = next((parent for parent in (resolved.parent, *resolved.parents) if parent.name == ".vault"), None)
    if vault and vault.is_dir():
        with vault_lock(vault):
            yield
    else:
        yield


def scalar(value: Any) -> str:
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return str(value)
    if isinstance(value, (list, dict)):
        return json.dumps(value, ensure_ascii=False)
    return json.dumps(str(value).replace("\r", " ").replace("\n", " "), ensure_ascii=False)


def parse_scalar(value: str) -> Any:
    lowered = value.lower()
    if lowered == "true":
        return True
    if lowered == "false":
        return False
    if lowered == "null":
        return None
    try:
        return json.loads(value)
    except json.JSONDecodeError:
        return value


def parse_updates(values: list[str]) -> dict[str, Any]:
    updates: dict[str, Any] = {}
    for item in values:
        if "=" not in item:
            raise VaultError(f"Invalid update {item!r}; expected key=value")
        key, value = item.split("=", 1)
        if not KEY_RE.fullmatch(key):
            raise VaultError(f"Invalid field name: {key!r}")
        updates[key] = parse_scalar(value)
    if not updates:
        raise VaultError("At least one key=value update is required")
    return updates


def split_frontmatter(content: str) -> tuple[list[str], str]:
    lines = content.splitlines(keepends=True)
    if not lines or lines[0].strip() != "---":
        raise VaultError("Markdown file has no YAML frontmatter")
    for index in range(1, len(lines)):
        if lines[index].strip() == "---":
            frontmatter = [line.rstrip("\r\n") for line in lines[1:index]]
            return frontmatter, "".join(lines[index + 1 :])
    raise VaultError("Markdown file has malformed YAML frontmatter")


def parse_frontmatter(path: Path) -> tuple[dict[str, Any], str]:
    try:
        lines, body = split_frontmatter(path.read_text(encoding="utf-8"))
    except (OSError, VaultError):
        return {}, ""
    result: dict[str, Any] = {}
    for line in lines:
        if ":" not in line or line[:1].isspace():
            continue
        key, value = line.split(":", 1)
        key = key.strip()
        value = value.strip()
        if not KEY_RE.fullmatch(key):
            continue
        result[key] = parse_scalar(value)
    return result, body


def render_markdown(frontmatter: dict[str, Any], body: str) -> str:
    lines = ["---"]
    lines.extend(f"{key}: {scalar(value)}" for key, value in frontmatter.items())
    lines.extend(["---", ""])
    if body:
        lines.append(body.rstrip("\r\n"))
    return "\n".join(lines) + "\n"


def update_frontmatter_content(content: str, updates: dict[str, Any]) -> str:
    lines, body = split_frontmatter(content)
    output: list[str] = []
    consumed: set[str] = set()
    for line in lines:
        if ":" in line and not line[:1].isspace():
            key = line.split(":", 1)[0].strip()
            if key in updates:
                output.append(f"{key}: {scalar(updates[key])}")
                consumed.add(key)
                continue
        output.append(line)
    for key, value in updates.items():
        if key not in consumed:
            output.append(f"{key}: {scalar(value)}")
    return "---\n" + "\n".join(output) + "\n---\n" + body.lstrip("\r\n")


def instruction_block() -> str:
    plugin = Path(__file__).resolve().parent.parent
    path = plugin / "assets" / "VAULT-INSTRUCTIONS.md"
    if not path.is_file():
        raise VaultError(f"Plugin instructions are missing: {path}")
    return path.read_text(encoding="utf-8").rstrip() + "\n"


def ensure_instruction_file(path: Path, block: str) -> None:
    heading = "## Knowledge Vault"
    if path.exists():
        current = path.read_text(encoding="utf-8")
        if re.search(r"(?m)^## Knowledge Vault\s*$", current):
            return
        atomic_write_text(path, current.rstrip() + "\n\n" + block)
    else:
        atomic_write_text(path, block)


def default_state() -> dict[str, Any]:
    return {
        "version": 1,
        "last_compiled": None,
        "last_lint": None,
        "stats": {
            "source_count": 0,
            "compiled_count": 0,
            "pending_count": 0,
            "concept_count": 0,
            "summary_count": 0,
            "output_count": 0,
        },
    }


def configure_tracking(vault: Path, track: bool) -> None:
    ignore = vault / ".gitignore"
    if track:
        if ignore.is_file() and ignore.read_text(encoding="utf-8") == PRIVATE_GITIGNORE:
            ignore.unlink()
    elif not ignore.exists():
        atomic_write_text(ignore, PRIVATE_GITIGNORE)


def ensure_vault_skeleton(vault: Path) -> None:
    for relative in VAULT_DIRECTORIES:
        (vault / relative).mkdir(parents=True, exist_ok=True)
    if not (vault / "raw/.manifest.json").exists():
        atomic_write_json(vault / "raw/.manifest.json", {"version": 1, "sources": []})
    if not (vault / "wiki/.state.json").exists():
        atomic_write_json(vault / "wiki/.state.json", default_state())
    if not (vault / "wiki/index.md").exists():
        atomic_write_text(vault / "wiki/index.md", render_index([], [], [], [], utc_now()))
    if not (vault / "wiki/_backlinks.json").exists():
        atomic_write_json(vault / "wiki/_backlinks.json", {})
    if not (vault / "sources.json").exists():
        atomic_write_json(vault / "sources.json", {"version": 1, "configured_sources": [], "last_configured": None})
    if not (vault / "agent.md").exists():
        atomic_write_text(vault / "agent.md", agent_template())
    if not (vault / "preferences.md").exists():
        atomic_write_text(vault / "preferences.md", default_preferences())

    template_root = Path(__file__).resolve().parent.parent / "assets/templates"
    if template_root.is_dir():
        for source in template_root.glob("*.md"):
            target = vault / "templates" / source.name
            if not target.exists():
                shutil.copy2(source, target)


def command_init(args: argparse.Namespace) -> None:
    target = Path(args.target).resolve()
    vault = target / ".vault"
    target.mkdir(parents=True, exist_ok=True)
    block = instruction_block()

    if vault.exists() and not vault.is_dir():
        raise VaultError(f"Vault path exists but is not a directory: {vault}")
    if vault.exists():
        ensure_vault_skeleton(vault)
        ensure_instruction_file(target / "CLAUDE.md", block)
        ensure_instruction_file(target / "AGENTS.md", block)
        configure_tracking(vault, args.track)
        print(f"Vault already exists at {vault}")
        return

    ensure_vault_skeleton(vault)
    configure_tracking(vault, args.track)

    ensure_instruction_file(target / "CLAUDE.md", block)
    ensure_instruction_file(target / "AGENTS.md", block)
    print(f"Vault initialized at {vault}")


def default_preferences() -> str:
    return render_markdown(
        {"title": "Vault Preferences", "updated": utc_now()},
        "## Domain\n\nGeneral research\n\n"
        "## Source Priority\n\nPrefer primary and peer-reviewed sources when available.\n\n"
        "## Concept Granularity\n\nbalanced\n\n"
        "## Compilation Focus\n\nPreserve methods, quantitative findings, and limitations.\n\n"
        "## Custom Rules\n\nNone.",
    )


def agent_template() -> str:
    return """---
title: Vault Agent
version: 1
updated: null
vault_stats:
  total_queries: 0
  total_compiles: 0
  cache_hits: 0
  tier3_fallbacks: 0
---

## Concept Clusters

_No clusters discovered yet._

## Query Patterns

_No patterns recorded yet._

## Source Signals

_No source signals yet._

## Corrections

_No corrections logged._
"""


def validate_request(payload: Any) -> dict[str, Any]:
    if not isinstance(payload, dict):
        raise VaultError("Ingest request must be a JSON object")
    for key in ("slug", "title", "type"):
        if not isinstance(payload.get(key), str) or not payload[key].strip():
            raise VaultError(f"Ingest request requires a non-empty {key!r}")
    if not SLUG_RE.fullmatch(payload["slug"]):
        raise VaultError("Slug may contain only letters, numbers, dots, underscores, and hyphens")
    if payload["type"] not in SOURCE_TYPES:
        raise VaultError(f"Unsupported source type: {payload['type']}")
    tags = payload.get("tags", [])
    if not isinstance(tags, list) or not all(isinstance(tag, str) for tag in tags):
        raise VaultError("tags must be an array of strings")
    for section in ("frontmatter", "manifest"):
        value = payload.get(section, {})
        if not isinstance(value, dict):
            raise VaultError(f"{section} must be an object")
        if section == "frontmatter":
            invalid = [key for key in value if not KEY_RE.fullmatch(key)]
            if invalid:
                raise VaultError(f"Invalid frontmatter fields: {', '.join(invalid)}")
            reserved = sorted(INGEST_FRONTMATTER_RESERVED & value.keys())
            if reserved:
                raise VaultError(f"Reserved frontmatter fields: {', '.join(reserved)}")
        else:
            reserved = sorted(INGEST_MANIFEST_RESERVED & value.keys())
            if reserved:
                raise VaultError(f"Reserved manifest fields: {', '.join(reserved)}")
    if payload.get("on_conflict", "error") not in {"error", "suffix"}:
        raise VaultError("on_conflict must be error or suffix")
    original = payload.get("original")
    if original is not None:
        if not isinstance(original, dict) or not isinstance(original.get("path"), str):
            raise VaultError("original must contain a path string")
        if original.get("mode", "copy") not in {"copy", "move"}:
            raise VaultError("original.mode must be copy or move")
    if "body_file" in payload and not isinstance(payload["body_file"], str):
        raise VaultError("body_file must be a string")
    return payload


def cleanup_request_files(payload: dict[str, Any], request_path: Path) -> None:
    body_file = payload.get("body_file")
    if isinstance(body_file, str):
        body_path = Path(body_file)
        if not body_path.is_absolute():
            body_path = (request_path.parent / body_path).resolve()
        try:
            body_path.relative_to(request_path.parent)
        except ValueError:
            pass
        else:
            body_path.unlink(missing_ok=True)
    request_path.unlink(missing_ok=True)


def is_pdf(path: Path) -> bool:
    try:
        with path.open("rb") as handle:
            return b"%PDF-" in handle.read(1024)
    except OSError:
        return False


def request_body(payload: dict[str, Any], request_path: Path) -> str:
    has_body = "body" in payload
    has_file = "body_file" in payload
    if has_body and has_file:
        raise VaultError("Use either body or body_file, not both")
    if has_file:
        body_path = Path(payload["body_file"])
        if not body_path.is_absolute():
            body_path = (request_path.parent / body_path).resolve()
        try:
            return body_path.read_text(encoding="utf-8")
        except OSError as error:
            raise VaultError(f"Cannot read body_file {body_path}: {error}") from error
    body = payload.get("body", "")
    if not isinstance(body, str):
        raise VaultError("body must be a string")
    return body


def pending_index(content: str, slug: str, source_type: str) -> str:
    if not SLUG_RE.fullmatch(slug):
        raise VaultError(f"Invalid source slug: {slug!r}")
    if source_type not in SOURCE_TYPES:
        raise VaultError(f"Unsupported source type: {source_type!r}")
    heading = re.search(r"(?m)^## Pending Compilation \(\d+\)\s*$", content)
    if not heading:
        raise VaultError("Vault index has no Pending Compilation section")
    next_heading = re.search(r"(?m)^## ", content[heading.end() :])
    section_end = heading.end() + (next_heading.start() if next_heading else len(content[heading.end() :]))
    section = content[heading.end() : section_end]
    entries: list[tuple[str, str]] = []
    for match in re.finditer(r"(?m)^- `([^`]+)` \(([^)]+)\)\s*$", section):
        if match.group(1) != slug:
            entries.append((match.group(1), match.group(2)))
    entries.append((slug, source_type))
    entries.sort(key=lambda item: item[0])
    replacement = f"## Pending Compilation ({len(entries)})\n\n"
    replacement += "\n".join(f"- `{item_slug}` ({item_type})" for item_slug, item_type in entries)
    replacement += "\n\n"
    return content[: heading.start()] + replacement + content[section_end:].lstrip("\r\n")


def command_ingest(args: argparse.Namespace) -> None:
    request_path = Path(args.request).resolve()
    payload = validate_request(load_json(request_path))
    vault = require_vault(args.vault).resolve()
    manifest_path = vault / "raw/.manifest.json"
    index_path = vault / "wiki/index.md"
    timestamp = payload.get("ingested") or utc_now()
    body = request_body(payload, request_path)

    with vault_lock(vault):
        manifest = load_manifest(manifest_path)
        request_manifest = payload.get("manifest", {})
        zotero_key = request_manifest.get("zotero_key")
        if zotero_key:
            for item in manifest["sources"]:
                if isinstance(item, dict) and item.get("zotero_key") == zotero_key:
                    if args.cleanup_request:
                        cleanup_request_files(payload, request_path)
                    print(json.dumps({"status": "skipped", "slug": item.get("slug"), "reason": "zotero item already ingested"}))
                    return
        base_slug = payload["slug"]
        slug = base_slug
        number = 2
        existing_slugs = {item.get("slug") for item in manifest["sources"] if isinstance(item, dict)}
        while (vault / "raw" / f"{slug}.md").exists() or slug in existing_slugs or any((vault / "originals").glob(f"{slug}.*")):
            if payload.get("on_conflict", "error") != "suffix":
                raise VaultError(f"Slug already exists: {slug}")
            slug = f"{base_slug}-{number}"
            number += 1
        raw_path = vault / "raw" / f"{slug}.md"
        index_before = index_path.read_text(encoding="utf-8")
        manifest_before = manifest_path.read_text(encoding="utf-8")

        frontmatter: dict[str, Any] = {
            "title": payload["title"],
            "source": payload.get("source", ""),
            "type": payload["type"],
            "ingested": timestamp,
            "tags": payload.get("tags", []),
            "compiled": False,
        }
        frontmatter.update(payload.get("frontmatter", {}))

        original_source: Path | None = None
        original_target: Path | None = None
        staged_original: Path | None = None
        original_mode = "copy"
        original = payload.get("original")
        if original:
            original_source = Path(original["path"])
            if not original_source.is_absolute():
                original_source = (request_path.parent / original_source).resolve()
            if not original_source.is_file():
                raise VaultError(f"Original file not found: {original_source}")
            suffix = original.get("extension") or original_source.suffix
            if not isinstance(suffix, str) or not re.fullmatch(r"\.[A-Za-z0-9]{1,12}", suffix):
                raise VaultError(f"Unsafe original extension: {suffix!r}")
            original_target = vault / "originals" / f"{slug}{suffix.lower()}"
            if original_target.exists() and original_target.resolve() != original_source.resolve():
                raise VaultError(f"Original target already exists: {original_target}")
            original_mode = original.get("mode", "copy")
            if original_target.resolve() != original_source.resolve():
                descriptor, temporary = tempfile.mkstemp(prefix=f".{slug}.", suffix=suffix, dir=original_target.parent)
                os.close(descriptor)
                staged_original = Path(temporary)
                shutil.copy2(original_source, staged_original)
            frontmatter["original_path"] = f"originals/{original_target.name}"
            frontmatter["original_filename"] = original.get("filename") or original_source.name

        raw_content = render_markdown(frontmatter, body)
        manifest_entry: dict[str, Any] = {
            "slug": slug,
            "title": payload["title"],
            "file": f"{slug}.md",
            "type": payload["type"],
            "ingested": timestamp,
            "compiled": False,
            "tags": payload.get("tags", []),
        }
        manifest_entry.update(request_manifest)
        manifest["sources"].append(manifest_entry)
        index_after = pending_index(index_before, slug, payload["type"])

        committed: list[Path] = []
        try:
            atomic_write_text(raw_path, raw_content)
            committed.append(raw_path)
            if staged_original and original_target:
                os.replace(staged_original, original_target)
                committed.append(original_target)
            atomic_write_json(manifest_path, manifest)
            atomic_write_text(index_path, index_after)
        except Exception:
            for path in reversed(committed):
                path.unlink(missing_ok=True)
            atomic_write_text(manifest_path, manifest_before)
            atomic_write_text(index_path, index_before)
            raise
        finally:
            if staged_original:
                staged_original.unlink(missing_ok=True)

        move_warning: str | None = None
        if original_mode == "move" and original_source and original_target:
            if original_source.resolve() != original_target.resolve():
                try:
                    original_source.unlink()
                except OSError as error:
                    move_warning = f"ingest committed but source cleanup failed: {error}"

    if args.cleanup_request:
        cleanup_request_files(payload, request_path)
    result = {"status": "ingested", "slug": slug, "raw_file": str(raw_path)}
    if move_warning:
        result["warning"] = move_warning
    print(json.dumps(result, ensure_ascii=False))


def validate_attach_request(payload: Any) -> dict[str, Any]:
    if not isinstance(payload, dict):
        raise VaultError("Attachment request must be a JSON object")
    slug = payload.get("slug")
    if not isinstance(slug, str) or not SLUG_RE.fullmatch(slug):
        raise VaultError("Attachment request requires a safe slug")
    original = payload.get("original")
    if not isinstance(original, dict) or not isinstance(original.get("path"), str):
        raise VaultError("Attachment request requires original.path")
    if original.get("mode", "copy") not in {"copy", "move"}:
        raise VaultError("original.mode must be copy or move")
    if original.get("expected", "file") not in {"file", "pdf"}:
        raise VaultError("original.expected must be file or pdf")
    for section in ("frontmatter", "manifest"):
        value = payload.get(section, {})
        if not isinstance(value, dict):
            raise VaultError(f"{section} must be an object")
        invalid = [key for key in value if not KEY_RE.fullmatch(key)]
        if invalid:
            raise VaultError(f"Invalid {section} fields: {', '.join(invalid)}")
        reserved = {"ingested", "original_filename", "original_path", "source", "tags", "title", "type"}
        if section == "manifest":
            reserved |= {"file", "slug"}
        conflicts = sorted(reserved & value.keys())
        if conflicts:
            raise VaultError(f"Reserved {section} fields: {', '.join(conflicts)}")
    if "body_file" in payload and not isinstance(payload["body_file"], str):
        raise VaultError("body_file must be a string")
    if not isinstance(payload.get("mark_pending", False), bool):
        raise VaultError("mark_pending must be true or false")
    return payload


def command_attach_original(args: argparse.Namespace) -> None:
    request_path = Path(args.request).resolve()
    payload = validate_attach_request(load_json(request_path))
    vault = require_vault(args.vault).resolve()
    slug = payload["slug"]
    raw_path = vault / "raw" / f"{slug}.md"
    manifest_path = vault / "raw/.manifest.json"
    index_path = vault / "wiki/index.md"
    original = payload["original"]
    source = Path(original["path"])
    if not source.is_absolute():
        source = (request_path.parent / source).resolve()
    if not source.is_file():
        raise VaultError(f"Original file not found: {source}")
    if original.get("expected") == "pdf" and not is_pdf(source):
        raise VaultError(f"Recovered file is not a PDF: {source}")
    suffix = original.get("extension") or source.suffix
    if not isinstance(suffix, str) or not re.fullmatch(r"\.[A-Za-z0-9]{1,12}", suffix):
        raise VaultError(f"Unsafe original extension: {suffix!r}")
    target = vault / "originals" / f"{slug}{suffix.lower()}"
    mode = original.get("mode", "copy")
    body: str | None = None
    body_file = payload.get("body_file")
    if body_file:
        body_path = Path(body_file)
        if not body_path.is_absolute():
            body_path = (request_path.parent / body_path).resolve()
        if not body_path.is_file():
            raise VaultError(f"Body file not found: {body_path}")
        body = body_path.read_text(encoding="utf-8")

    move_warning: str | None = None
    with vault_lock(vault):
        if not raw_path.is_file():
            raise VaultError(f"Raw source not found: {raw_path}")
        manifest = load_manifest(manifest_path)
        manifest_entry = next(
            (item for item in manifest["sources"] if isinstance(item, dict) and item.get("slug") == slug),
            None,
        )
        if manifest_entry is None:
            raise VaultError(f"Slug not found in manifest: {slug}")
        source_is_target = source.resolve() == target.resolve()
        if target.exists() and not source_is_target:
            raise VaultError(f"Original target already exists: {target}")

        raw_before = raw_path.read_text(encoding="utf-8")
        manifest_before = manifest_path.read_text(encoding="utf-8")
        index_before = index_path.read_text(encoding="utf-8")
        updates = dict(payload.get("frontmatter", {}))
        updates["original_path"] = f"originals/{target.name}"
        updates["original_filename"] = original.get("filename") or source.name
        raw_after = update_frontmatter_content(raw_before, updates)
        if body is not None:
            frontmatter_lines, _ = split_frontmatter(raw_after)
            raw_after = "---\n" + "\n".join(frontmatter_lines) + "\n---\n\n" + body.rstrip("\r\n") + "\n"
        manifest_entry.update(payload.get("manifest", {}))
        index_after = index_before
        if payload.get("mark_pending"):
            index_after = pending_index(index_before, slug, str(manifest_entry.get("type", "?")))

        staged: Path | None = None
        created_target = False
        try:
            if not source_is_target:
                descriptor, temporary = tempfile.mkstemp(prefix=f".{slug}.", suffix=suffix, dir=target.parent)
                os.close(descriptor)
                staged = Path(temporary)
                shutil.copy2(source, staged)
                if original.get("expected") == "pdf" and not is_pdf(staged):
                    raise VaultError(f"Staged recovery is not a PDF: {source}")
            atomic_write_text(raw_path, raw_after)
            if staged:
                os.replace(staged, target)
                created_target = True
            atomic_write_json(manifest_path, manifest)
            if index_after != index_before:
                atomic_write_text(index_path, index_after)
        except Exception:
            atomic_write_text(raw_path, raw_before)
            atomic_write_text(manifest_path, manifest_before)
            atomic_write_text(index_path, index_before)
            if created_target:
                target.unlink(missing_ok=True)
            raise
        finally:
            if staged:
                staged.unlink(missing_ok=True)

        if mode == "move" and not source_is_target:
            try:
                source.unlink()
            except OSError as error:
                move_warning = f"attachment committed but source cleanup failed: {error}"

    if args.cleanup_request:
        cleanup_request_files(payload, request_path)
    result = {"status": "attached", "slug": slug, "original_path": f"originals/{target.name}"}
    if move_warning:
        result["warning"] = move_warning
    print(json.dumps(result, ensure_ascii=False))


def command_index_add(args: argparse.Namespace) -> None:
    vault = require_vault(args.vault)
    index = vault / "wiki/index.md"
    with vault_lock(vault):
        content = index.read_text(encoding="utf-8")
        atomic_write_text(index, pending_index(content, args.slug, args.type))
    print(f"Indexed pending source: {args.slug}")


def command_update_frontmatter(args: argparse.Namespace) -> None:
    path = Path(args.file)
    if not path.is_file():
        raise VaultError(f"File not found: {path}")
    updates = parse_updates(args.updates)
    with path_lock(path):
        content = path.read_text(encoding="utf-8")
        atomic_write_text(path, update_frontmatter_content(content, updates))
    print(f"Updated {path}: {', '.join(updates)}")


def command_replace_body(args: argparse.Namespace) -> None:
    path = Path(args.file)
    body_path = Path(args.body_file)
    if not path.is_file() or not body_path.is_file():
        raise VaultError("replace-body requires existing markdown and body files")
    with path_lock(path):
        frontmatter, _ = split_frontmatter(path.read_text(encoding="utf-8"))
        body = body_path.read_text(encoding="utf-8")
        content = "---\n" + "\n".join(frontmatter) + "\n---\n\n" + body.rstrip("\r\n") + "\n"
        atomic_write_text(path, content)
    if args.cleanup:
        body_path.unlink(missing_ok=True)
    print(f"Replaced body in {path}")


def command_update_manifest(args: argparse.Namespace) -> None:
    vault = require_vault(args.vault)
    path = vault / "raw/.manifest.json"
    updates = parse_updates(args.updates)
    immutable = {"file", "ingested", "slug", "title", "type"} & updates.keys()
    if immutable:
        raise VaultError(f"Cannot update immutable manifest fields: {', '.join(sorted(immutable))}")
    with vault_lock(vault):
        manifest = load_manifest(path)
        for source in manifest.get("sources", []):
            if source.get("slug") == args.slug:
                source.update(updates)
                validate_manifest_data(manifest, path)
                atomic_write_json(path, manifest)
                print(f"Updated {args.slug}: {', '.join(updates)}")
                return
    raise VaultError(f"Slug not found in manifest: {args.slug}")


def command_mark_compiled(args: argparse.Namespace) -> None:
    vault = require_vault(args.vault).resolve()
    raw_path = vault / "raw" / f"{args.slug}.md"
    summary_path = vault / "wiki/summaries" / f"{args.slug}.md"
    manifest_path = vault / "raw/.manifest.json"
    with vault_lock(vault):
        if not raw_path.is_file():
            raise VaultError(f"Raw source not found: {raw_path}")
        if not summary_path.is_file():
            raise VaultError(f"Cannot mark compiled without a summary: {summary_path}")
        raw_before = raw_path.read_text(encoding="utf-8")
        manifest_before = manifest_path.read_text(encoding="utf-8")
        manifest = load_manifest(manifest_path)
        entry = next(
            (item for item in manifest["sources"] if isinstance(item, dict) and item.get("slug") == args.slug),
            None,
        )
        if entry is None:
            raise VaultError(f"Slug not found in manifest: {args.slug}")
        raw_after = update_frontmatter_content(raw_before, {"compiled": True})
        entry["compiled"] = True
        try:
            atomic_write_text(raw_path, raw_after)
            atomic_write_json(manifest_path, manifest)
        except Exception:
            atomic_write_text(raw_path, raw_before)
            atomic_write_text(manifest_path, manifest_before)
            raise
    print(f"Marked compiled: {args.slug}")


def command_update_state(args: argparse.Namespace) -> None:
    vault = require_vault(args.vault)
    path = vault / "wiki/.state.json"
    updates = parse_updates(args.updates)
    with vault_lock(vault):
        state = load_json(path) if path.exists() else {"version": 1}
        if not isinstance(state, dict):
            raise VaultError(f"State has an invalid structure: {path}")
        state.update(updates)
        atomic_write_json(path, state)
    print(f"Updated {path}: {', '.join(updates)}")


def slugify(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode("ascii").lower()
    return re.sub(r"[^a-z0-9]+", "-", normalized).strip("-")


def command_derive_slug(args: argparse.Namespace) -> None:
    parts = [slugify(value) for value in (args.entity, args.year, args.keyword) if slugify(value)]
    base = "-".join(parts) or "untitled"
    vault = Path(args.vault)
    candidate = base
    number = 2
    while (vault / "raw" / f"{candidate}.md").exists() or any((vault / "originals").glob(f"{candidate}.*")):
        candidate = f"{base}-{number}"
        number += 1
    print(candidate)


def link_target(value: str) -> str:
    target = value.split("|", 1)[0].split("#", 1)[0].strip().lower().replace(" ", "-")
    return target


def markdown_escape(value: Any, *, preserve_brackets: bool = False) -> str:
    text = html.escape(str(value).replace("\r", " ").replace("\n", " "), quote=False)
    text = text.replace("\\", "\\\\").replace("|", "\\|")
    if not preserve_brackets:
        text = text.replace("[", "\\[").replace("]", "\\]")
    return text


def markdown_path(value: str) -> str:
    return quote(value, safe="/-._~")


def render_index(
    summaries: list[dict[str, Any]],
    pending: list[dict[str, Any]],
    concepts: list[dict[str, Any]],
    outputs: list[dict[str, Any]],
    updated: str,
) -> str:
    lines = ["---", 'title: "Vault Index"', f"updated: {scalar(updated)}", "---", "", "# Vault Index", ""]
    lines.extend([f"## Source Summaries ({len(summaries)} compiled)", ""])
    if summaries:
        lines.extend(["| Source | Type | Concepts |", "|---|---|---|"])
        for row in summaries:
            concept_slugs = [
                str(item)
                for item in row.get("concepts", [])
                if isinstance(item, str) and SLUG_RE.fullmatch(item)
            ][:4]
            links = ", ".join(f"[[{item}]]" for item in concept_slugs)
            summary_href = markdown_path(f"summaries/{row['slug']}.md")
            lines.append(
                f"| [{markdown_escape(row['title'])}]({summary_href}) | "
                f"{markdown_escape(row['type'])} | {markdown_escape(links, preserve_brackets=True)} |"
            )
    else:
        lines.append("_No sources compiled yet._")
    lines.extend(["", f"## Pending Compilation ({len(pending)})", ""])
    if pending:
        lines.extend(f"- `{row['slug']}` ({row.get('type', '?')})" for row in pending)
    else:
        lines.append("_No sources pending._")
    lines.extend(["", f"## Concepts ({len(concepts)})", ""])
    if concepts:
        lines.extend(["| Concept | Sources |", "|---|---|"])
        for row in concepts:
            concept_href = markdown_path(f"concepts/{row['slug']}.md")
            lines.append(
                f"| [{markdown_escape(row['title'])}]({concept_href}) | {row['source_count']} |"
            )
    else:
        lines.append("_No concepts extracted yet._")
    lines.extend(["", "## Recent Outputs", ""])
    if outputs:
        for row in outputs:
            output_href = markdown_path(f"outputs/{row['slug']}.md")
            lines.append(
                f"- [{markdown_escape(row['title'])}]({output_href}) "
                f"({row['created'][:10]})"
            )
    else:
        lines.append("_No queries filed yet._")
    return "\n".join(lines) + "\n"


def command_rebuild(args: argparse.Namespace) -> None:
    vault = require_vault(args.vault)
    wiki = vault / "wiki"
    manifest_path = vault / "raw/.manifest.json"
    with vault_lock(vault):
        manifest = load_manifest(manifest_path)
        sources = manifest.get("sources", [])
        pending = sorted((item for item in sources if not item.get("compiled")), key=lambda item: item.get("slug", ""))
        summaries: list[dict[str, Any]] = []
        missing_summaries: list[str] = []
        disconnected: list[str] = []
        for source in (item for item in sources if item.get("compiled")):
            slug = source.get("slug", "")
            path = wiki / "summaries" / f"{slug}.md"
            if not path.is_file():
                missing_summaries.append(slug)
                continue
            frontmatter, body = parse_frontmatter(path)
            concepts = frontmatter.get("concepts_extracted", [])
            if not isinstance(concepts, list):
                concepts = [item.strip() for item in str(concepts).strip("[]").split(",") if item.strip()]
            summaries.append(
                {
                    "slug": slug,
                    "title": source.get("title", slug),
                    "type": source.get("type", "?"),
                    "concepts": concepts,
                    "ingested": source.get("ingested", ""),
                }
            )
            if not WIKILINK_RE.search(body):
                disconnected.append(slug)
        summaries.sort(key=lambda item: item["ingested"], reverse=True)

        concepts: list[dict[str, Any]] = []
        for path in sorted((wiki / "concepts").glob("*.md")):
            frontmatter, _ = parse_frontmatter(path)
            source_list = frontmatter.get("sources", [])
            if not isinstance(source_list, list):
                source_list = [item.strip() for item in str(source_list).strip("[]").split(",") if item.strip()]
            concepts.append(
                {
                    "slug": path.stem,
                    "title": frontmatter.get("title", path.stem),
                    "source_count": len(source_list),
                }
            )
        concepts.sort(key=lambda item: str(item["title"]).lower())

        output_paths = [path for path in (wiki / "outputs").glob("*.md") if not path.name.startswith("lint-")]
        outputs: list[dict[str, Any]] = []
        for path in sorted(output_paths, key=lambda item: item.stat().st_mtime, reverse=True)[:5]:
            frontmatter, _ = parse_frontmatter(path)
            outputs.append(
                {"slug": path.stem, "title": frontmatter.get("title", path.stem), "created": str(frontmatter.get("created", ""))}
            )

        now = utc_now()
        atomic_write_text(wiki / "index.md", render_index(summaries, pending, concepts, outputs, now))
        backlinks: dict[str, list[str]] = {}
        for path in list((wiki / "concepts").glob("*.md")) + list((wiki / "summaries").glob("*.md")) + output_paths:
            content = path.read_text(encoding="utf-8")
            for raw_link in WIKILINK_RE.findall(content):
                target = link_target(raw_link)
                if target:
                    backlinks.setdefault(target, [])
                    if path.stem not in backlinks[target]:
                        backlinks[target].append(path.stem)
        atomic_write_json(wiki / "_backlinks.json", backlinks)

        state_path = wiki / ".state.json"
        if state_path.exists():
            state = load_json(state_path)
            if not isinstance(state, dict):
                raise VaultError(f"State has an invalid structure: {state_path}")
        else:
            state = default_state()
        state["stats"] = {
            "source_count": len(sources),
            "compiled_count": sum(1 for item in sources if item.get("compiled")),
            "pending_count": len(pending),
            "concept_count": len(concepts),
            "summary_count": len(summaries),
            "output_count": len(output_paths),
        }
        state["last_rebuilt"] = now
        atomic_write_json(state_path, state)

    print(
        json.dumps(
            {
                "sources": len(sources),
                "summaries": len(summaries),
                "concepts": len(concepts),
                "outputs": len(output_paths),
                "missing_summaries": missing_summaries,
                "disconnected_summaries": disconnected,
            }
        )
    )


def command_lint(args: argparse.Namespace) -> None:
    vault = require_vault(args.vault)
    wiki = vault / "wiki"
    findings: dict[str, list[str]] = {
        "critical": [],
        "stale": [],
        "missing_concepts": [],
        "orphaned": [],
        "thin": [],
        "duplicate_aliases": [],
        "originals": [],
        "trees": [],
    }
    manifest_path = vault / "raw/.manifest.json"
    try:
        manifest = load_manifest(manifest_path)
        sources = manifest["sources"]
    except VaultError as error:
        findings["critical"].append(str(error))
        sources = []
    seen_slugs: set[str] = set()
    for index, item in enumerate(sources):
        if not isinstance(item, dict):
            findings["critical"].append(f"manifest source {index}: entry must be an object")
            continue
        slug = item.get("slug")
        if not isinstance(slug, str) or not SLUG_RE.fullmatch(slug):
            findings["critical"].append(f"manifest source {index}: invalid slug {slug!r}")
            continue
        if slug in seen_slugs:
            findings["critical"].append(f"manifest source {slug}: duplicate entry")
        seen_slugs.add(slug)
    source_slugs = seen_slugs
    compiled_slugs = {
        item.get("slug")
        for item in sources
        if isinstance(item, dict) and item.get("slug") in source_slugs and item.get("compiled") is True
    }
    raw_slugs = {path.stem for path in (vault / "raw").glob("*.md")}
    for slug in sorted(source_slugs - raw_slugs):
        findings["critical"].append(f"manifest source {slug}: raw file missing")
    for slug in sorted(raw_slugs - source_slugs):
        findings["orphaned"].append(f"raw/{slug}.md: missing from manifest")
    for slug in sorted(compiled_slugs):
        if not (wiki / "summaries" / f"{slug}.md").is_file():
            findings["critical"].append(f"compiled source {slug}: summary file missing")
    for item in sources:
        if not isinstance(item, dict) or item.get("slug") not in raw_slugs:
            continue
        slug = item["slug"]
        raw_frontmatter, _ = parse_frontmatter(vault / "raw" / f"{slug}.md")
        if not raw_frontmatter:
            findings["critical"].append(f"raw/{slug}.md: missing or malformed frontmatter")
        elif raw_frontmatter.get("compiled") is not item.get("compiled"):
            findings["critical"].append(f"source {slug}: raw and manifest compiled state differ")

    state_path = wiki / ".state.json"
    try:
        state = load_json(state_path)
        if not isinstance(state, dict) or not isinstance(state.get("stats"), dict):
            raise VaultError(f"State has an invalid structure: {state_path}")
    except VaultError as error:
        findings["critical"].append(str(error))

    concept_slugs: set[str] = set()
    aliases: dict[str, set[str]] = {}
    for path in (wiki / "concepts").glob("*.md"):
        concept_slugs.add(path.stem)
        frontmatter, body = parse_frontmatter(path)
        source_list = frontmatter.get("sources", [])
        if not isinstance(source_list, list):
            source_list = [item.strip() for item in str(source_list).strip("[]").split(",") if item.strip()]
        if source_list and not frontmatter.get("updated"):
            findings["stale"].append(f"concepts/{path.name}: sources present but updated date missing")
        if not source_list:
            findings["orphaned"].append(f"concepts/{path.name}: zero sources linked")
        words = len(body.split())
        if words < 100:
            findings["thin"].append(f"concepts/{path.name}: {words} words (minimum 100)")
        alias_list = frontmatter.get("aliases", [])
        if not isinstance(alias_list, list):
            alias_list = [item.strip() for item in str(alias_list).strip("[]").split(",") if item.strip()]
        aliases[path.stem] = {str(frontmatter.get("title", path.stem)).lower(), *(str(item).lower() for item in alias_list)}

    markdown_paths = list((wiki / "concepts").glob("*.md")) + list((wiki / "summaries").glob("*.md")) + list((wiki / "outputs").glob("*.md"))
    for path in markdown_paths:
        for raw_link in WIKILINK_RE.findall(path.read_text(encoding="utf-8")):
            target = link_target(raw_link)
            if target and target not in concept_slugs and not (wiki / "summaries" / f"{target}.md").is_file():
                findings["missing_concepts"].append(f"{path.relative_to(wiki)}: [[{raw_link}]] has no target")
    names = sorted(aliases)
    for index, left in enumerate(names):
        for right in names[index + 1 :]:
            overlap = aliases[left] & aliases[right]
            if overlap:
                findings["duplicate_aliases"].append(f"{left} <-> {right}: {sorted(overlap)}")

    for path in (wiki / "summaries").glob("*.md"):
        if path.stem not in source_slugs:
            findings["orphaned"].append(f"summaries/{path.name}: missing from manifest")
    for path in (vault / "raw").glob("*.md"):
        frontmatter, _ = parse_frontmatter(path)
        original = frontmatter.get("original_path")
        if original and not (vault / str(original)).is_file():
            findings["originals"].append(f"raw/{path.name}: original_path {original!r} not found")
        if frontmatter.get("has_tree") is True:
            tree = vault / "raw" / f"{path.stem}.tree.json"
            try:
                load_json(tree)
            except VaultError as error:
                findings["trees"].append(str(error))
    for path in (vault / "originals").glob("*"):
        if path.is_file() and path.stem not in raw_slugs:
            findings["originals"].append(f"originals/{path.name}: no matching raw file")

    warnings = sum(len(values) for key, values in findings.items() if key not in {"critical", "thin"})
    payload = {
        "critical": len(findings["critical"]),
        "warnings": warnings,
        "suggestions": len(findings["thin"]),
        "findings": findings,
    }
    print(json.dumps(payload, indent=2, ensure_ascii=False))
    if findings["critical"]:
        raise SystemExit(2)


def command_status(args: argparse.Namespace) -> None:
    vault = require_vault(args.vault)
    manifest = load_manifest(vault / "raw/.manifest.json")
    try:
        state = load_json(vault / "wiki/.state.json")
        if not isinstance(state, dict):
            raise VaultError("Vault state must be an object")
    except VaultError:
        state = {}
    sources = manifest.get("sources", [])
    pending = [item for item in sources if not item.get("compiled")]
    stats = state.get("stats", {})
    if not isinstance(stats, dict):
        stats = {}
    configured = []
    try:
        source_config = load_json(vault / "sources.json")
        if not isinstance(source_config, dict) or not isinstance(source_config.get("configured_sources", []), list):
            raise VaultError("Source configuration must be an object with configured_sources")
        configured = [
            item
            for item in source_config.get("configured_sources", [])
            if isinstance(item, dict) and item.get("enabled")
        ]
    except VaultError:
        pass
    clippings = len(list((vault / "Clippings").glob("*.md"))) + len(list((vault / "inbox").glob("*")))
    print("=== Knowledge Vault Status ===")
    print(f"Sources:    {len(sources)} total, {len(sources) - len(pending)} compiled, {len(pending)} pending")
    for source in pending:
        print(f"  - {source.get('slug', '?')} ({source.get('type', '?')})")
    print(f"Concepts:   {stats.get('concept_count', 0)}")
    print(f"Summaries:  {stats.get('summary_count', 0)}")
    print(f"Outputs:    {stats.get('output_count', 0)}")
    print(f"Research:   {len(configured)} configured")
    print(f"Inbox:      {clippings} waiting")


def command_agent_reset(args: argparse.Namespace) -> None:
    vault = require_vault(args.vault)
    with vault_lock(vault):
        atomic_write_text(vault / "agent.md", agent_template())
    print("Agent reset. Retrieval patterns cleared.")


def render_tree_node(node: Any, depth: int, output: list[str]) -> None:
    if not isinstance(node, dict):
        return
    title = str(node.get("title") or "(untitled)").strip()
    start, end = node.get("start_index"), node.get("end_index")
    pages = f"  *(pages {start}-{end})*" if start is not None and end is not None else ""
    output.extend([f"{'#' * min(max(depth, 2), 6)} {title}{pages}", ""])
    summary = str(node.get("summary") or "").strip()
    if summary:
        output.extend([summary, ""])
    for child in node.get("nodes") or []:
        render_tree_node(child, depth + 1, output)


def command_render_tree(args: argparse.Namespace) -> None:
    tree = load_json(Path(args.tree))
    if isinstance(tree, dict):
        nodes = tree.get("nodes", tree.get("structure", []))
        description = tree.get("doc_description")
    elif isinstance(tree, list):
        nodes = tree
        description = None
    else:
        raise VaultError("Tree JSON must be an object or array")
    output: list[str] = []
    if description:
        output.extend(["## Overview", "", str(description).strip(), ""])
    for node in nodes:
        render_tree_node(node, 2, output)
    rendered = "\n".join(output).rstrip() + "\n"
    if args.output:
        atomic_write_text(Path(args.output), rendered)
        print(f"Rendered tree to {args.output}")
    else:
        print(rendered, end="")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    init = subparsers.add_parser("init", help="Initialize a project vault")
    init.add_argument("target", nargs="?", default=".")
    init.add_argument("--track", action="store_true", help="Do not create the privacy-first .vault/.gitignore")
    init.set_defaults(handler=command_init)

    ingest = subparsers.add_parser("ingest", help="Atomically ingest a structured request")
    ingest.add_argument("--request", required=True)
    ingest.add_argument("--vault", default=".vault")
    ingest.add_argument("--cleanup-request", action="store_true")
    ingest.set_defaults(handler=command_ingest)

    attach = subparsers.add_parser("attach-original", help="Atomically attach a recovered source artifact")
    attach.add_argument("--request", required=True)
    attach.add_argument("--vault", default=".vault")
    attach.add_argument("--cleanup-request", action="store_true")
    attach.set_defaults(handler=command_attach_original)

    index_add = subparsers.add_parser("index-add", help="Idempotently add a pending index entry")
    index_add.add_argument("slug")
    index_add.add_argument("type")
    index_add.add_argument("--vault", default=".vault")
    index_add.set_defaults(handler=command_index_add)

    frontmatter = subparsers.add_parser("update-frontmatter")
    frontmatter.add_argument("file")
    frontmatter.add_argument("updates", nargs="+")
    frontmatter.set_defaults(handler=command_update_frontmatter)

    replace_body = subparsers.add_parser("replace-body")
    replace_body.add_argument("file")
    replace_body.add_argument("body_file")
    replace_body.add_argument("--cleanup", action="store_true")
    replace_body.set_defaults(handler=command_replace_body)

    manifest = subparsers.add_parser("update-manifest")
    manifest.add_argument("slug")
    manifest.add_argument("updates", nargs="+")
    manifest.add_argument("--vault", default=".vault")
    manifest.set_defaults(handler=command_update_manifest)

    compiled = subparsers.add_parser("mark-compiled", help="Atomically mark a source compiled after its summary exists")
    compiled.add_argument("slug")
    compiled.add_argument("--vault", default=".vault")
    compiled.set_defaults(handler=command_mark_compiled)

    state = subparsers.add_parser("update-state")
    state.add_argument("vault")
    state.add_argument("updates", nargs="+")
    state.set_defaults(handler=command_update_state)

    derive = subparsers.add_parser("derive-slug")
    derive.add_argument("entity")
    derive.add_argument("year")
    derive.add_argument("keyword")
    derive.add_argument("vault", nargs="?", default=".vault")
    derive.set_defaults(handler=command_derive_slug)

    rebuild = subparsers.add_parser("rebuild")
    rebuild.add_argument("vault", nargs="?", default=".vault")
    rebuild.set_defaults(handler=command_rebuild)

    lint = subparsers.add_parser("lint")
    lint.add_argument("vault", nargs="?", default=".vault")
    lint.set_defaults(handler=command_lint)

    status = subparsers.add_parser("status")
    status.add_argument("vault", nargs="?", default=".vault")
    status.set_defaults(handler=command_status)

    reset = subparsers.add_parser("agent-reset")
    reset.add_argument("vault", nargs="?", default=".vault")
    reset.set_defaults(handler=command_agent_reset)

    render_tree = subparsers.add_parser("render-tree")
    render_tree.add_argument("tree")
    render_tree.add_argument("--output")
    render_tree.set_defaults(handler=command_render_tree)
    return parser


def main() -> None:
    args = build_parser().parse_args()
    try:
        args.handler(args)
    except (VaultError, OSError) as error:
        print(f"Error: {error}", file=sys.stderr)
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()
