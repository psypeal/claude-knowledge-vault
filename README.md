# Knowledge Vault

A local research knowledge base for Codex and Claude Code. Ingest papers, URLs, notes, and Zotero collections; compile linked summaries and concepts; ask grounded questions; browse the result in Obsidian.

[![Release](https://img.shields.io/github/v/release/psypeal/knowledge-vault)](https://github.com/psypeal/knowledge-vault/releases)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Codex](https://img.shields.io/badge/Codex-plugin-111827.svg)](https://developers.openai.com/codex/plugins)
[![Claude Code](https://img.shields.io/badge/Claude_Code-plugin-7C3AED.svg)](https://docs.anthropic.com/en/docs/claude-code)

## What it does

- Stores each vault inside the current project under `.vault/`.
- Preserves source artifacts and creates compact Markdown extracts.
- Compiles sources into an Obsidian-compatible wiki with `[[wikilinks]]`.
- Answers questions from the vault before falling back to source documents.
- Optionally searches academic MCP sources and imports Zotero collections.
- Optionally builds PageIndex trees for targeted PDF retrieval.

The core workflows require Python 3.10 or newer and run on Linux, macOS, and Windows. External research sources, Poppler PDF extraction, and PageIndex tree indexing are optional.

## Install

### Codex

```bash
codex plugin marketplace add psypeal/knowledge-vault
codex plugin add knowledge-vault@knowledge-vault
```

In Codex, invoke `@knowledge-vault` or ask naturally:

```text
Initialize a knowledge vault in this project.
Add this PDF to my knowledge vault.
Compile the pending vault sources.
Answer this question from my knowledge vault: ...
```

### Claude Code

```text
/plugin marketplace add psypeal/knowledge-vault
/plugin install knowledge-vault@knowledge-vault
/reload-plugins
```

Claude Code supports the same natural-language requests plus `/knowledge-vault:*` commands.

## Quick start

1. Initialize the vault:

   ```text
   Initialize a knowledge vault in this project.
   ```

2. Add material:

   ```text
   Add https://example.com/article to my knowledge vault.
   Add ./papers/example.pdf to my knowledge vault.
   Add these meeting notes to my knowledge vault: ...
   ```

3. Compile pending sources:

   ```text
   Compile my knowledge vault.
   ```

4. Ask a grounded question:

   ```text
   Ask my knowledge vault: What evidence supports this conclusion?
   ```

Knowledge Vault adds concise project guidance to both `AGENTS.md` and `CLAUDE.md`, so either host recognizes an initialized vault later.

New vaults also include `.vault/.gitignore`, so research material stays out of version control by default. Advanced users can run the core initializer with `--track` to opt in deliberately.

## Workflows

| Workflow | Natural-language example | Claude Code command |
|---|---|---|
| Initialize | `Initialize a knowledge vault` | `/knowledge-vault:init` |
| Ingest | `Add this URL/PDF/note to the vault` | `/knowledge-vault:ingest` |
| Import Zotero | `Import my neuroimaging Zotero collection` | `/knowledge-vault:ingest-zotero` |
| Collect papers | `Find recent papers about ...` | `/knowledge-vault:collect` |
| Compile | `Compile pending vault sources` | `/knowledge-vault:compile` |
| Query | `Ask the vault: ...` | `/knowledge-vault:query` |
| Enrich references | `Find full text for reference-only items` | `/knowledge-vault:enrich-references` |
| Process inbox | `Process the vault inbox` | `/knowledge-vault:process` |
| Check health | `Lint the knowledge vault` | `/knowledge-vault:lint` |
| Repair wiki | `Clean up the compiled vault` | `/knowledge-vault:cleanup` |
| Configure sources | `Set up research sources` | `/knowledge-vault:setup-sources` |
| Show status | `Show vault status` | `/knowledge-vault:status` |

## Vault layout

```text
.vault/
├── .gitignore               Privacy-first Git exclusion
├── agent.md                 Retrieval hints learned from repeated queries
├── inbox/                   Files waiting for the process workflow
├── originals/               Preserved PDFs, HTML, and other source artifacts
├── preferences.md           Domain and compilation preferences
├── raw/
│   ├── .manifest.json       Source state
│   ├── <slug>.md            Compact extracted source
│   └── <slug>.tree.json     Optional PageIndex tree
├── sources.json             Enabled research-source preferences
├── templates/
└── wiki/
    ├── concepts/            Cross-source concept articles
    ├── summaries/           Per-source summaries
    ├── outputs/             Filed answers and lint reports
    ├── _backlinks.json
    ├── .state.json
    └── index.md
```

Open `.vault/` directly in Obsidian to browse links and graph relationships. Use plugin workflows to modify generated wiki content so manifests and indexes stay consistent.

## Architecture

- One canonical `knowledge-vault` skill routes every workflow in Codex and Claude Code.
- Claude Code slash commands are manual wrappers over that same skill, not independent implementations.
- `scripts/kv.py` owns manifest/index state transitions, locking, atomic writes, rollback, rebuilds, and linting.
- Source-derived values travel through JSON request files rather than shell interpolation.
- Legacy `.sh` entry points remain as compatibility adapters; current workflows call Python directly.

## Optional integrations

Run `Set up research sources for my knowledge vault` to detect and configure integrations. The setup workflow uses the correct command for the active host.

| Integration | Purpose | Requirement |
|---|---|---|
| Consensus | Evidence-focused academic search | MCP registration |
| arXiv | Search and download preprints | `uvx`, `arxiv-mcp-server==0.5.0`, and MCP registration |
| Paper Search | Search multiple academic indexes | Node.js, `paper-search-mcp-nodejs@0.2.7`, and MCP registration |
| Zotero | Collections, metadata, full text, annotations | Zotero 7 and `zotero-mcp-server==0.6.1` |
| Unpaywall | Open-access PDF discovery by DOI | `UNPAYWALL_EMAIL` |
| PageIndex | Hierarchical PDF tree retrieval | Optional Python environment and model API key |
| Sci-Hub | Optional DOI-based retrieval fallback | Explicit opt-in and legal review |

Codex and Claude Code store MCP configuration differently. In particular, the current Codex CLI registers MCP servers in user configuration; the plugin still requires a per-vault `.vault/.scihub-enabled` marker before it will use the optional Sci-Hub integration.

PageIndex supports `OPENAI_API_KEY` or `ANTHROPIC_API_KEY`. Set `KNOWLEDGE_VAULT_PAGEINDEX_MODEL` to override the default LiteLLM model. API keys remain in the user's environment and are never copied into the plugin or vault.

## Update and remove

Codex:

```bash
codex plugin marketplace upgrade knowledge-vault
codex plugin add knowledge-vault@knowledge-vault
```

To remove it:

```bash
codex plugin remove knowledge-vault@knowledge-vault
```

Claude Code:

```text
/plugin marketplace update knowledge-vault
/reload-plugins
/plugin uninstall knowledge-vault@knowledge-vault
```

Removing the plugin does not delete project `.vault/` directories.

## Existing vaults

The `.vault/` format remains backward compatible. Re-running initialization refreshes missing `AGENTS.md` or `CLAUDE.md` guidance without replacing vault data.

Installs from `2.4.1` or earlier may still use the old marketplace name. Re-add it once:

```text
/plugin marketplace remove claude-knowledge-vault
/plugin marketplace add psypeal/knowledge-vault
/plugin install knowledge-vault@knowledge-vault
```

For v2.3 vaults, run cleanup to backfill preserved originals and optional PageIndex trees. Existing slugs remain unchanged so wikilinks do not break.

If upgrading from the original standalone Claude skill, remove it before installing the plugin:

```bash
rm -rf ~/.claude/skills/knowledge-vault
```

## Privacy

Vault content stays in the project's `.vault/` directory and is ignored by Git by default. Knowledge Vault has no telemetry or hosted service. The active AI host and any optional integrations process data under their own terms; see [PRIVACY.md](PRIVACY.md).

Vaults may contain sensitive or copyrighted material. Remove or override `.vault/.gitignore` only when you intentionally want to commit vault contents.

## Development

Run the cross-platform runtime tests:

```bash
python3 tests/test_kv.py
```

On a POSIX host with Codex and/or Claude Code installed, run the complete plugin validation suite:

```bash
bash tests/validate-plugin.sh
```

The older model-driven evaluation harness remains under `eval/` for workflow regression experiments.

Release history is in [CHANGELOG.md](CHANGELOG.md).

## Credits

Knowledge Vault builds on ideas from [Andrej Karpathy's LLM knowledge-base workflow](https://x.com/karpathy/status/1906365823148564901), [agno-agi/pal](https://github.com/agno-agi/pal), and [farzaa/wiki](https://github.com/farzaa/wiki). Optional PDF indexing installs a pinned revision of [VectifyAI/PageIndex](https://github.com/VectifyAI/PageIndex) under its MIT license.

## License

[MIT](LICENSE)
