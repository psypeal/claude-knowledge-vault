## Knowledge Vault

This project has a local knowledge vault at `.vault/`. Use the Knowledge Vault plugin through natural language. Claude Code also supports `/knowledge-vault:*` slash commands.

**Layout**:
- `originals/` — preserved source files (PDF, EPUB, HTML) renamed to slug (`<author-year-keyword>.<ext>`)
- `raw/<slug>.md` — extracted/condensed body, with optional sidecar `<slug>.tree.json` (PageIndex tree)
- `wiki/` — AI-maintained summaries, concepts, and index.

Core workflows: initialize, ingest, collect, compile, query, process, lint, cleanup, configure sources, and show status.

Consult the vault only when the user asks. Keep generated wiki content under `.vault/wiki/` and retrieval hints in `.vault/agent.md`; update them through plugin workflows rather than ad hoc edits.
