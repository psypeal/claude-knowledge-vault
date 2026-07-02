---
description: Answer a question grounded in vault knowledge (4-tier reasoning routing)
argument-hint: <question>
---

Question: `$ARGUMENTS`

## Procedure

A 4-tier cascade: stop at the lowest tier that answers the question. Compiled knowledge is fast and usually enough; trees and originals are reserved for ground-truth detail.

### Tier 1 — Index
Read `.vault/wiki/index.md`. Pick 2-4 candidate items (summaries or concepts) likely to hold the answer.

### Tier 2 — Compiled knowledge
Read those 2-4 files in `wiki/concepts/` and `wiki/summaries/`. **Most queries should end here.** If the answer is plain enough from compiled knowledge, write it concisely with `[[wikilinks]]` to sources and stop.

### Tier 3 — Tree reasoning (PageIndex)
Drop here only when tier 2 lacks the *specific* detail (an exact statistic, a numeric threshold, a paragraph the user wants quoted, a methodology subtlety). For each candidate source slug:
1. Check whether `.vault/raw/<slug>.tree.json` exists.
2. Read the tree — it's a hierarchical TOC with `title`, `summary`, `start_index`, `end_index` (page numbers).
3. Reason over titles + summaries to identify the *single section* most likely to hold the answer. Capture its `start_index` and `end_index`.

If no tree exists for any candidate, skip to tier 4 with the raw markdown body instead.

### Tier 4 — Source extraction
Pull just the relevant pages from the original document. Preflight: `command -v pdftotext` — if missing, tell the user once to install poppler-utils (`sudo apt install poppler-utils` / `brew install poppler`) and answer from the tier-2/3 material instead.

```bash
pdftotext -f <start_index> -l <end_index> .vault/originals/<slug>.pdf -
```

(For non-PDF originals: read `.vault/raw/<slug>.md` directly — there's no tree-driven page extraction.)

Read that excerpt, then answer with the precise quote/figure/number, citing both `[[wiki/summaries/<slug>]]` and the page range.

## Files NOT to read

`preferences.md`, `agent.md`, `agent-update-rules.md`, `writing-rules.md`, `_backlinks.json`, `.manifest.json`, `.state.json`, `sources.json`, the `vendor/` directory, or anything in `.vault/Clippings/` or `.vault/inbox/`. Stay in the four-tier path above.

## When to do more

**File the answer** ONLY when the user says "file it" or "save this". Then write to `wiki/outputs/` and run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/rebuild-index.sh"`.

**Update agent.md** ONLY after 3+ queries in the same session. Then read `${CLAUDE_PLUGIN_ROOT}/skills/vault-operations/references/agent-update-rules.md`.

**Agent pre-routing** ONLY if `total_queries >= 5` in agent.md. Read it before the index.

## Notes

- **Cost discipline**: tier 3 reads a JSON tree (small); tier 4 reads only the page range identified by tier 3. We never load whole PDFs into context.
- **Graceful degradation**: vaults from v2.3.0 have no trees and no `originals/`. Tier 3 silently skips; tier 4 falls back to reading `raw/<slug>.md`. The query still works.
- **Track tier-3/4 fallbacks**: when answering required tier 3 or 4, increment `vault_stats.tier3_fallbacks` in `.vault/agent.md` next time it's updated. High counts suggest the corresponding wiki summary should be expanded by the next compile.
