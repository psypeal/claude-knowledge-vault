# Changelog

All notable changes for Knowledge Vault.

## [2.4.2] - 2026-06-11

### Fixed — v2.4.1 regressions

- **Restored `${CLAUDE_PLUGIN_ROOT}` in all command/agent/skill files.** The 2.4.1 rewrite to `${CLAUDE_PLUGIN_ROOT:-${CODEX_PLUGIN_ROOT:-.}}` defeated Claude Code's literal template substitution (`/\$\{CLAUDE_PLUGIN_ROOT\}/g`), breaking every scripted step of every command. `hooks/hooks.json` keeps the fallback form — hooks receive the variable as an environment variable, so shell expansion resolves it there.
- **Completed the marketplace rename.** Root `.claude-plugin/marketplace.json` now declares `name: knowledge-vault` and version `2.4.2` (it was left at `claude-knowledge-vault` / `2.4.0`, so the README's install commands referenced a marketplace that didn't exist and update checks never saw 2.4.1). The duplicate `plugins/knowledge-vault/.claude-plugin/marketplace.json` was removed. README documents the one-time re-add for users of the old marketplace name.
- **Codex MCP detection now reads `~/.codex/config.toml`** (`[mcp_servers]` sections, via tomllib) instead of `.codex.json` / `~/.codex/settings.json`, which real Codex installs don't have.

### Fixed — hardening (v2.4.0 audit findings)

- `/process` clippings are now registered in `raw/.manifest.json` via `ingest.sh` — previously they never entered the manifest, so `/compile` silently skipped them and the next index rebuild erased them.
- `ingest-zotero.sh` accepts `type` and `has_fulltext` parameters (previously hardcoded `paper`, never wrote `has_fulltext` — so `/enrich-references` always found 0 candidates).
- `/setup-sources` no longer writes an empty PageIndex `.env` when `ANTHROPIC_API_KEY` is unset (which made detection report PageIndex as configured while every tree build silently failed); detection now also requires a non-empty key inside `.env`.
- `/ingest` no longer instructs a tree build before the slug exists (chicken-and-egg that either dead-ended or double-billed the PageIndex run).
- `/cleanup` backfill verifies recovered files are actual PDFs for every recovery method, and no longer treats Zotero fulltext (extracted text) as PDF bytes.
- `init.sh` creates `.vault/inbox/` (the documented `/process` drop location).
- Shell-into-Python injection removed: `update-frontmatter.sh`, `index-append.sh`, `vault-status.sh` now pass values via argv — paths/slugs containing apostrophes no longer crash (or execute) anything.
- `ingest.sh` / `ingest-zotero.sh` validate the manifest before writing the raw file (a corrupt manifest no longer leaves orphaned raw files that block re-runs).
- `build-tree.sh`: dependency probe covers `PyPDF2` + `yaml` (partial installs now exit 2 "deps missing" instead of 5 "run failed"); output basename now matches `run_pageindex.py`'s `splitext` for non-lowercase `.PDF` extensions.
- `detect-mcp-sources.sh`: also scans `.mcp.json` (where `claude mcp add -s project` writes — Sci-Hub was undetectable), deduplicates entries, and skips malformed config files instead of crashing with exit 0.
- `update-frontmatter.sh` quotes YAML values containing `: ` (previously produced invalid YAML).
- Friendlier failure modes: `render-tree-outline.sh` and `rebuild-index.sh` print one-line errors instead of tracebacks; `update-state.sh` no longer dies silently on zero args; the session hook tolerates a corrupt manifest.
- `/init` stops instead of overwriting `preferences.md` when the vault already exists; `/query` tier 4 preflights `pdftotext`; `/process` confirms before batch tree-building more than 3 PDFs.
- Docs: removed the stale "No PDFs are stored in the vault" claim (v2.4 deliberately preserves them in `originals/`); README shows the real tree.json shape; repo-root `LICENSE` added; `VAULT-CLAUDE.md` lists all 13 commands; `VENDORED.md` update recipe excludes `.env`; skill renamed to match its directory (`vault-operations`); `vault-collector` agent aligned with v2.4 bibliographic slugs.

### Known limitations (upstream PageIndex, unmodified)

- No page cap / concurrency limit on very large PDFs; retry exhaustion can yield empty summaries; scanned image-only PDFs still spend tokens producing a junk tree. Tracked for a future vendored update.

## [2.4.1] - 2026-05-28

### Added

- Added Codex marketplace support so the plugin is installable and manageable in Codex while retaining Claude Code compatibility.
- Normalized plugin IDs and install identifiers to `knowledge-vault` across marketplace and plugin manifests.
- Added Codex-specific manifest at `plugins/knowledge-vault/.codex-plugin/plugin.json`.
- Added dedicated marketplace metadata at `plugins/knowledge-vault/.claude-plugin/marketplace.json`.
- Bumped plugin metadata versions to `2.4.1`.

## [2.4.0] - 2026-05-07

### Added

- Introduced per-PDF hierarchical PageIndex tree indexing workflow.
- Preserved original source files under `originals/<slug>.<ext>` with backward-compatible upgrade support.
- Switched paper identification to bibliographic-style slugs.
- Added 4-tier retrieval path in `/knowledge-vault:query` (wiki, tree, and page extraction).

## [2.3.0] - 2026-04-23

### Changed

- Decoupled optional Sci-Hub flow from Unpaywall.
- Relaxed user confirmation requirements for source setup steps.
