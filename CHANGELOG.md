# Changelog

All notable changes for Knowledge Vault.

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
