---
name: knowledge-vault
description: Operate a local knowledge-base vault (.vault/ directory) within any project. This skill should be used when the user says "vault init", "vault ingest", "vault compile", "vault lint", "vault query", "vault process", "vault status", "add to vault", "ask the vault", "check the vault", or references the .vault/ directory. The vault ingests raw sources, compiles them into a wiki of summaries and concept articles with cross-references, lints for consistency, and supports grounded Q&A.
---

# Knowledge Vault

A local, project-scoped knowledge base operated entirely by Claude. Raw sources are ingested, compiled into a wiki of summaries and concept articles, and queried on demand. The user browses in Obsidian but never edits wiki content directly.

## Directory Structure

```
.vault/
  Clippings/          Obsidian Web Clipper landing zone (default folder)
  raw/                Ingested sources with YAML frontmatter
    .manifest.json    Source registry
  wiki/               LLM-compiled knowledge base
    index.md          Master routing index (ALWAYS read first)
    concepts/         One article per topic
    summaries/        One summary per raw source
    outputs/          Filed query results and lint reports
    .state.json       Compilation and lint state
  templates/          Frontmatter skeletons for common types
```

## File Schemas

### Raw Source (`raw/<slug>.md`)

Slug: lowercase, hyphens for spaces, max 60 characters. Derived from the title.

```yaml
---
title: "Human-Readable Title"
source: "URL or origin identifier"
type: paper|article|repo|dataset|meeting|notes|clip
ingested: "ISO 8601 UTC timestamp"
tags: [tag1, tag2]
compiled: false
---

Content body here.
```

### Manifest (`raw/.manifest.json`)

```json
{
  "version": 1,
  "sources": [
    {
      "slug": "the-slug",
      "title": "The Title",
      "file": "the-slug.md",
      "type": "paper",
      "ingested": "2026-04-03T14:22:00Z",
      "compiled": false,
      "tags": ["tag1", "tag2"]
    }
  ]
}
```

### Wiki State (`wiki/.state.json`)

```json
{
  "version": 1,
  "last_compiled": "ISO timestamp or null",
  "last_lint": "ISO timestamp or null",
  "stats": {
    "source_count": 0,
    "compiled_count": 0,
    "pending_count": 0,
    "concept_count": 0,
    "summary_count": 0,
    "output_count": 0
  }
}
```

### Summary Article (`wiki/summaries/<slug>.md`)

```yaml
---
title: "Summary: Original Title"
source_file: "raw/the-slug.md"
source_type: paper
compiled: "ISO timestamp"
concepts_extracted: [concept-a, concept-b]
word_count: 350
---

200-500 word summary. Include:
- Key findings or contributions
- Methods (if applicable)
- Relevance to this project
```

### Concept Article (`wiki/concepts/<slug>.md`)

```yaml
---
title: "Concept Name"
aliases: [alternative-name, abbreviation]
created: "ISO timestamp"
updated: "ISO timestamp"
sources: [source-slug-1, source-slug-2]
related: [other-concept-slug]
---

200-500 word synthesis of what the vault knows about this concept.

## Key Points
- ...

## Source Evidence
- From [[source-slug-1]]: "relevant quote or finding"
- From [[source-slug-2]]: "relevant quote or finding"

## Related Concepts
- [[Other Concept]] — brief explanation of the relationship
```

### Wiki Index (`wiki/index.md`)

```yaml
---
title: Vault Index
updated: "ISO timestamp"
---
```

Contains three tables:
1. **Source Summaries**: slug, type, one-line summary, linked concepts
2. **Pending Compilation**: list of uncompiled raw files
3. **Concepts**: concept name, number of linked sources, one-line description
4. **Recent Outputs**: recent query results and lint reports

---

## Operations

### vault init

Initialize a vault in the current project.

1. Run: `bash ~/.claude/skills/knowledge-vault/scripts/init.sh`
2. This creates `.vault/` with empty structure and appends instructions to CLAUDE.md.
3. Confirm to the user that the vault is ready and suggest opening `.vault/` in Obsidian.

### vault ingest

Add a raw source to the vault. Accepts: URL, file path, pasted text, or MCP tool output.

**Procedure:**

1. Determine the source type:
   - URL → fetch with WebFetch, set `type: clip` or `type: article`
   - PubMed/Scholar MCP result → set `type: paper`
   - Pasted text → set `type: notes`
   - File path → read the file, infer type from context
2. Generate a slug from the title (lowercase, hyphens, max 60 chars).
3. Run: `bash ~/.claude/skills/knowledge-vault/scripts/ingest.sh "<slug>" "<title>" "<type>" [tags...]`
4. Fill in the content body of the created `raw/<slug>.md` using the Write or Edit tool.
5. If the source is a URL, set the `source:` field in the frontmatter.
6. Update `wiki/index.md` — add the new source to the "Pending Compilation" section.

**If using a template:** Check `.vault/templates/` for a matching type. Use its structure for the content body.

### vault compile

Process uncompiled raw sources into wiki articles.

**Procedure:**

1. Read `raw/.manifest.json`. Identify entries where `compiled: false`.
   - If the user names a specific source, compile only that one.
   - Otherwise, compile all pending.
2. For each uncompiled source:
   a. Read the raw file in full.
   b. **Create summary**: Write `wiki/summaries/<slug>.md` (200-500 words). Include key findings, methods, relevance. Set `concepts_extracted` in frontmatter.
   c. **Extract concepts**: Identify 2-6 key concepts from the source.
   d. **For each concept**:
      - If `wiki/concepts/<concept-slug>.md` exists: update it — add new source evidence, update the `sources` list, update `updated` timestamp, expand the article if the new source adds significant information.
      - If it does not exist: create it with an initial 200-500 word article.
   e. **Cross-reference**: Update `related` fields in affected concept articles. Use `[[wikilinks]]` in article bodies for Obsidian compatibility.
   f. **Mark compiled**: Set `compiled: true` in the raw file's YAML frontmatter. Update the manifest entry.
3. **Rebuild index**: Regenerate `wiki/index.md` from the manifest and concept file list. Source table sorted by ingestion date (newest first). Concept table sorted alphabetically.
4. **Update state**: Update `wiki/.state.json` with new counts and `last_compiled` timestamp.

**Concept slug rules**: Lowercase, hyphens, max 60 chars. Example: "Self-Attention" → `self-attention`.

**Cross-reference rules**: When a concept article mentions another concept that has its own article, use `[[concept-name]]` wikilink syntax. Update the `related` field in both articles.

### vault lint

Run 7 health checks on the wiki.

**Procedure:**

1. Read `wiki/index.md` and scan all concept and summary articles.
2. Run these checks:

| # | Check | What to look for | Severity |
|---|-------|-------------------|----------|
| 1 | **Contradictions** | Claims in different articles that conflict. Cite both sources. | Critical |
| 2 | **Stale articles** | Concepts whose `updated` is older than the newest source in their `sources` list. | Warning |
| 3 | **Missing concepts** | Terms referenced via `[[wikilink]]` that have no concept article. | Warning |
| 4 | **Orphaned articles** | Concept articles with zero entries in `sources`, or summaries whose raw file is missing. | Warning |
| 5 | **Thin articles** | Concept articles under 100 words. | Suggestion |
| 6 | **Duplicate concepts** | Articles covering the same topic (check `aliases` overlap and title similarity). | Warning |
| 7 | **Gap analysis** | Based on existing concepts, suggest missing topics that would strengthen the knowledge graph. | Suggestion |

3. Write the report to `wiki/outputs/lint-YYYY-MM-DD.md` with findings grouped by check.
4. Update `wiki/.state.json` with `last_lint` timestamp.
5. Print a summary: "Vault lint: X critical, Y warnings, Z suggestions."

### vault query

Answer a question grounded in the vault's knowledge.

**Procedure:**

1. **Read index first**: Read `wiki/index.md` to understand what the vault contains.
2. **Identify relevant articles**: From the index tables, pick summaries and concepts that are relevant to the question.
3. **Read articles**: Read the identified summaries and concept articles (Tier 2). Only go to raw sources (Tier 3) if summaries lack sufficient detail.
4. **Answer**: Compose an answer grounded in the vault content. Use `[[wikilinks]]` to reference source articles inline.
5. **File (optional)**: If the user says "file it" or the answer is substantial, write it to `wiki/outputs/<descriptive-slug>.md` with frontmatter:

```yaml
---
title: "Q: The question asked"
query: "The original question"
created: "ISO timestamp"
sources_consulted: [slug1, slug2]
concepts_referenced: [concept-a, concept-b]
---
```

6. Update `wiki/index.md` recent outputs section if an output was filed.

**3-tier routing strategy:**
- Tier 1 (always): `wiki/index.md` — scan for relevance
- Tier 2 (on demand): `wiki/summaries/` and `wiki/concepts/` — read relevant articles
- Tier 3 (rarely): `raw/` — read full source only when needed

### vault process

Batch operation: ingest all Clippings, then compile all pending.

**Procedure:**

1. Scan `.vault/Clippings/` for `.md` files (Obsidian Web Clipper's default folder).
2. For each file:
   a. Read the file. Extract title and metadata from YAML frontmatter (Obsidian Web Clipper format).
   b. Generate a slug from the title.
   c. Move the file to `raw/<slug>.md` (ensure frontmatter matches the vault schema — reformat if needed).
   d. Add entry to `raw/.manifest.json`.
3. After all clippings are ingested, run the **vault compile** procedure on all pending sources.
4. Report: "Processed N clippings, compiled M sources, extracted K new concepts."

### vault status

Print a quick summary of the vault state.

1. Run: `bash ~/.claude/skills/knowledge-vault/scripts/vault-status.sh`
2. Display the output to the user.

---

## Integration Notes

### Obsidian

The `.vault/` directory is designed as an Obsidian vault:
- All files use YAML frontmatter (Obsidian reads this natively)
- Cross-references use `[[wikilinks]]` (Obsidian's native linking)
- Concept `aliases` in frontmatter enable Obsidian alias resolution
- Graph View visualizes concept connections
- Dataview plugin can query frontmatter (e.g., `TABLE title, type, compiled FROM "raw"`)

Obsidian Web Clipper saves to `Clippings/` by default — no configuration needed. Just set the clipper's vault to the project's `.vault/` directory and clips land in the right place automatically.

### Telegram Notifications

After long operations (compile with 3+ sources, lint), notify via:
```bash
~/claude-telegram-bridge/scripts/notify "Vault: compiled 5 sources, 3 new concepts"
```

### MCP Research Tools

When ingesting from PubMed or Scholar-Gateway MCP tools, set `type: paper` and populate the `source` field with the DOI or PubMed URL. Use the article metadata for tags.

### Git Commits

Use structured commit messages for vault operations:
- `vault: ingest <slug> (<type>)`
- `vault: compile <N> sources`
- `vault: lint (<N> issues found)`
- `vault: query filed <slug>`
- `vault: process <N> inbox items`
