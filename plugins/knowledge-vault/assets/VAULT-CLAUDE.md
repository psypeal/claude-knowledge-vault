
## Knowledge Vault

This project has a knowledge vault at `.vault/`. Use `/knowledge-vault:*` commands or natural language.

**Layout**:
- `originals/` — preserved source files (PDF, EPUB, HTML) renamed to slug (`<author-year-keyword>.<ext>`)
- `raw/<slug>.md` — extracted/condensed body, with optional sidecar `<slug>.tree.json` (PageIndex tree)
- `wiki/` — Claude-maintained summaries, concepts, index. Never edit by hand.

**Commands**: `/knowledge-vault:init`, `/knowledge-vault:ingest`, `/knowledge-vault:ingest-zotero`, `/knowledge-vault:compile`, `/knowledge-vault:lint`, `/knowledge-vault:cleanup`, `/knowledge-vault:query`, `/knowledge-vault:process`, `/knowledge-vault:collect`, `/knowledge-vault:enrich-references`, `/knowledge-vault:setup-sources`, `/knowledge-vault:status`, `/knowledge-vault:agent-reset`

The vault is not consulted unless explicitly asked. All wiki content is maintained by Claude — do not edit `.vault/wiki/` or `.vault/agent.md` files manually.
