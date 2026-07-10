# Changelog

All notable changes for Knowledge Vault.

## [2.6.0] - 2026-07-10

### Added

- Added a Python 3.10+ cross-platform vault CLI with atomic ingestion, recovered-original attachment and compile-state transitions, locking, rollback, structured downloads, and bounded PDF extraction.
- Added Linux, macOS, and Windows regression coverage plus native Codex and Claude Code manifest/install validation in GitHub Actions.
- Added Codex composer and marketplace artwork.

### Changed

- Made pending-index writes idempotent and made rebuild/lint report compiled sources whose summary files are missing.
- Routed all Claude Code commands through the canonical shared skill and disabled duplicate automatic command invocation.
- Replaced source-derived shell arguments in ingest, enrichment, and backfill workflows with structured JSON requests.
- Escaped untrusted metadata in generated Markdown and validated manifest slugs before using them as paths.
- Pinned optional MCP packages and PageIndex/Sci-Hub revisions, and documented the required Consensus OAuth login for Codex.
- Made vault contents private by default with `.vault/.gitignore`; `init --track` remains an explicit opt-in to version control.
- Retained shell scripts only as backward-compatible adapters around the cross-platform Python implementation.

### Removed

- Removed the redundant session-start hook; initialized projects already carry durable `AGENTS.md` and `CLAUDE.md` guidance.

## [2.5.1] - 2026-07-10

### Changed

- Integrated the parallel `2.4.2` integrity audit into the native Codex architecture: manifest-first ingestion, Zotero full-text state, clipping registration, PDF validation, YAML-safe updates, and malformed metadata handling.
- Added root repository licensing and regression coverage for corrupt manifests, special-character paths, Zotero state, Codex installation, and Claude manifest validation.

## [2.5.0] - 2026-07-10

### Added

- Added one first-class Codex skill that routes every vault workflow while keeping Claude Code slash commands as thin wrappers over the same instructions.
- Added Codex-aware MCP detection and host-specific setup commands.
- Added `AGENTS.md` project guidance, OpenAI-backed PageIndex support, a privacy policy, and cross-host validation tests.

### Changed

- Consolidated marketplace metadata and removed the stale nested marketplace manifest.
- Consolidated workflow guidance into one lazily routed skill and removed the redundant collector agent.
- Made initialization idempotent and added the missing vault inbox directory.
- Replaced the long README with a concise Claude Code and Codex operator guide.
- Replaced the bundled PageIndex source tree with an opt-in installer pinned to a reviewed upstream revision.
- Stopped writing API keys into the installed plugin directory.

## [2.4.2] - 2026-06-11

### Fixed

- Restored literal `CLAUDE_PLUGIN_ROOT` usage in Claude command templates and completed the marketplace rename.
- Fixed clipping registration, Zotero full-text state, manifest-first ingestion, and malformed configuration handling.
- Removed shell-to-Python interpolation from helper scripts and added safer YAML, PDF, PageIndex, and status handling.
- Added the documented inbox directory and repository-root license.

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
