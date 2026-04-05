---
name: knowledge-vault
description: Operate a local knowledge-base vault (.vault/ directory) within any project. This skill should be used when the user says "vault init", "vault ingest", "vault compile", "vault lint", "vault query", "vault process", "vault cleanup", "vault status", "vault agent reset", "add to vault", "ask the vault", "check the vault", or references the .vault/ directory. The vault ingests raw sources, compiles them into a wiki of summaries and concept articles with cross-references, lints for consistency, and supports grounded Q&A.
---

# Knowledge Vault

A local, project-scoped knowledge base operated entirely by Claude. Raw sources are ingested, compiled into a wiki of summaries and concept articles, and queried on demand. The user browses in Obsidian but never edits wiki content directly.

## Directory Structure

```
.vault/
  preferences.md      User preferences (interview-generated, manually editable)
  agent.md            Learned retrieval intelligence (auto-maintained)
  Clippings/          Obsidian Web Clipper landing zone (default folder)
  raw/                Ingested sources with YAML frontmatter
    .manifest.json    Source registry
  wiki/               LLM-compiled knowledge base
    index.md          Master routing index (ALWAYS read first)
    _backlinks.json   Reverse link index (which articles link to which)
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

**Structure by source type** — different types call for different article structures:

| Source type | Structure emphasis |
|:-----------|:------------------|
| paper | Methods → Findings → Implications |
| article | Thesis → Evidence → Relevance |
| repo | Architecture → Key components → Usage |
| meeting | Decisions → Action items → Context |
| dataset | Variables → Coverage → Limitations |

### Backlinks Index (`wiki/_backlinks.json`)

Machine-readable reverse link index. Maps each article to every article that links to it.

```json
{
  "self-attention": ["transformer-architecture", "multi-head-attention", "positional-encoding"],
  "transformer-architecture": ["self-attention", "bert-overview"]
}
```

Rebuilt during `vault compile` step 3 and `vault cleanup`. Enables Claude to quickly find the most-connected concepts (high backlink count = central topic).

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

### Agent File (`.vault/agent.md`)

Auto-maintained by Claude. Users should NOT edit this file. Contains learned retrieval intelligence that improves query efficiency over time.

Hard ceiling: 6,000 characters. Read cost: ~1,000 tokens at maturity.

```yaml
---
title: Vault Agent
version: 1
updated: "ISO timestamp"
vault_stats:
  total_queries: 0
  total_compiles: 0
  cache_hits: 0
  tier3_fallbacks: 0
---
```

Four bounded sections:

| Section | Max entries | Purpose |
|---------|-----------|---------|
| **Concept Clusters** | 8 | Groups of concepts frequently co-accessed in queries |
| **Query Patterns** | 10 | Maps question keywords → specific articles that answer them |
| **Source Signals** | 15 | Tracks which sources are most frequently useful and for what topics |
| **Corrections** | 5 (FIFO) | Logs retrieval mistakes to prevent repeating them |

**Entry format**: One line per entry, ~120-150 characters. Example:
```
- {exposure-aging}: ambient-air-pollution, biological-age-acceleration | queries: 9 | last: 2026-04-15
```

**Minimum viable threshold**: agent.md is only read when `total_queries >= 3` OR `source_count >= 5`. Below this, index.md alone is sufficient.

---

## Operations

### vault init

Initialize a vault in the current project with personalized preferences.

**Procedure:**

1. Run: `bash ~/.claude/skills/knowledge-vault/scripts/init.sh`
2. This creates `.vault/` with empty structure and appends instructions to CLAUDE.md.
3. **Interview the user** to configure `.vault/preferences.md`. Ask these questions one at a time, adapting based on answers. Skip questions that are obvious from project context:

   a. **Domain**: "What domain is this vault for?" (e.g., ML research, biomedical science, web development, general)
   b. **Source types**: "What sources will you mainly use?" (papers, articles, code repos, meeting notes, web clips)
   c. **Priority rules**: "Any priority for sources?" (e.g., peer-reviewed over blog posts, recent over old, primary data over reviews)
   d. **Concept detail**: "How granular should concepts be?" (broad overview — fewer, larger articles / balanced / granular — many specific articles)
   e. **Compilation focus**: "Any special instructions for how sources should be summarized?" (e.g., always extract methodology, focus on clinical relevance, emphasize code architecture)

   If the user says "skip" or wants defaults, generate a sensible preferences file based on the project context.

4. Write `.vault/preferences.md` from the interview answers:

```yaml
---
title: Vault Preferences
updated: "ISO timestamp"
---

## Domain
[domain from interview]

## Source Priority
[priority rules — ranked list]

## Concept Granularity
[broad | balanced | granular]

## Compilation Focus
[specific instructions for how to summarize and extract concepts]

## Custom Rules
[any additional user-specified preferences]
```

5. Confirm to the user that the vault is ready and suggest opening `.vault/` in Obsidian.

**Preferences file contract:**
- Claude MUST read `.vault/preferences.md` at the start of every vault operation (compile, lint, query, process).
- The user may edit this file manually at any time. Claude always respects the latest version.
- During `vault compile`: preferences guide summary style, concept granularity, and what to prioritize in extraction.
- During `vault query`: preferences guide answer depth, source weighting, and domain framing.
- During `vault lint`: preferences inform what counts as "thin" or "stale" (domain-dependent).

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

0. **Read `.vault/preferences.md`** — apply domain, priority, granularity, and compilation focus to all steps below.
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
3. **Rebuild index and backlinks**: Regenerate `wiki/index.md` from the manifest and concept file list. Source table sorted by ingestion date (newest first). Concept table sorted alphabetically. Also rebuild `wiki/_backlinks.json` by scanning all `[[wikilinks]]` across concept articles and summaries.
4. **Update state**: Update `wiki/.state.json` with new counts and `last_compiled` timestamp.
5. **Update agent.md**: For each newly compiled source, add or update its entry in the Source Signals section of `.vault/agent.md`. Set initial cited count to 0. Record the source's primary topic domains based on concepts extracted. Increment `vault_stats.total_compiles`. Do NOT create Query Patterns from compilation (patterns are query-driven only).

**Concept slug rules**: Lowercase, hyphens, max 60 chars. Example: "Self-Attention" → `self-attention`.

**Cross-reference rules**: When a concept article mentions another concept that has its own article, use `[[concept-name]]` wikilink syntax. Update the `related` field in both articles.

**Writing quality rules** (apply to all summaries and concept articles):

- **Tone**: Write flat, factual, precise. State what the source found. Let data imply significance.
- **Avoid**: Peacock words ("groundbreaking", "revolutionary", "profound"), editorial voice ("interestingly", "importantly"), rhetorical questions, qualifiers ("truly", "deeply", "genuine").
- **Do**: Lead with the key finding. One claim per sentence. Short sentences. Simple past/present tense. Replace adjectives with specifics (numbers, dates, methods).
- **Quotes**: Maximum 2 direct quotes per article. Choose the most impactful.
- **Every article has a point**: Not "here are 4 sources that mention X" but "X is important because Y, supported by sources A, B."

**Anti-cramming rule**: If a concept article develops multiple distinct sub-topics (3+ paragraphs on different aspects), split into separate concept articles. Resist the gravitational pull of existing articles — create new pages rather than overstuffing.

**Anti-thinning rule**: Creating articles isn't the win; enriching them is. A stub with 2 vague sentences when 4 sources mention the topic is a failure. Every article must have real substance.

**Length targets**:

| Article type | Target lines |
|:-------------|:-------------|
| Concept (1-2 sources) | 20-40 |
| Concept (3+ sources) | 40-80 |
| Summary | 30-60 |
| Output (query result) | 20-50 |
| Minimum (anything) | 15 |

**Quality checkpoints** (during batch compile of 5+ sources): After every 5 compiled sources, pause and audit:
1. Rebuild `wiki/_backlinks.json` by scanning all `[[wikilinks]]` across articles
2. Check for zero new concept articles — if none were created, compilation is likely cramming
3. Re-read the 3 most-updated concept articles. Verify: theme-based organization (not just appended facts), cross-article connections via wikilinks, coherent narrative (not a chronological dump)
4. Flag concept articles exceeding 80 lines for potential splitting

### vault lint

Run 8 health checks on the wiki.

**Procedure:**

0. **Read `.vault/preferences.md`** — preferences inform what counts as "thin", "stale", or a priority gap.
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
| 8 | **Agent staleness** | agent.md references concepts or sources that no longer exist in the vault. Query patterns target deleted articles. | Warning |

3. Write the report to `wiki/outputs/lint-YYYY-MM-DD.md` with findings grouped by check.
4. Update `wiki/.state.json` with `last_lint` timestamp.
5. Print a summary: "Vault lint: X critical, Y warnings, Z suggestions."
6. If check 8 finds issues, automatically clean agent.md by removing references to non-existent content.

### vault query

Answer a question grounded in the vault's knowledge. Automatically classifies each query to maximize compounding value while avoiding noise.

**Procedure:**

0. **Read `.vault/preferences.md`**. If `.vault/agent.md` exists AND (`vault_stats.total_queries >= 3` OR `wiki/.state.json` stats.source_count >= 5), also read `.vault/agent.md`.
0.5. **Agent-directed pre-routing** (only if agent.md was read): Before reading index.md, scan agent.md Query Patterns for keyword matches against the user's question. If a pattern matches, note its suggested articles as priority reads. Also check Concept Clusters — if the query touches a concept in a cluster, plan to read the full cluster. Agent.md is advisory, NOT authoritative — always still read index.md in the next step.
1. **Read index first**: Read `wiki/index.md` to understand what the vault contains.
2. **Identify relevant articles**: From the index tables, pick summaries and concepts that are relevant to the question.
3. **Read articles**: Read the identified summaries and concept articles (Tier 2). Only go to raw sources (Tier 3) if summaries lack sufficient detail.
4. **Answer**: Compose an answer grounded in the vault content. Use `[[wikilinks]]` to reference source articles inline.
5. **Deduplication check**: Before filing, scan `wiki/outputs/` for existing outputs that cover the same question or connection. If a prior output already answers this query or documents the same connection, do NOT file a duplicate. Instead, reference the existing output in the answer. Only file if the new answer adds substantially new information or connections not covered by existing outputs.
6. **Classify and act**: After composing the answer, classify it using these concrete rules:

**Query classification (automatic):**

| Tier | Decision rule | Action |
|------|--------------|--------|
| **Synthesize** | Answer meets ALL of: (a) draws evidence from 2+ different raw sources, (b) identifies a relationship not already in any concept's `related` field, (c) the relationship is grounded in source evidence (not speculative) | File to `wiki/outputs/` with `strength` rating, update concept articles |
| **Record** | Answer meets ANY of: (a) 200+ words with structured analysis, (b) aggregates information across 3+ concept articles, (c) user explicitly says "file it" | File to `wiki/outputs/` only |
| **Skip** | Answer meets ANY of: (a) answers from a single source without new insight, (b) under 100 words, (c) purely factual lookup ("which sources mention X?"), (d) duplicate of an existing output | Answer only, do not file |

**When filing** (Synthesize or Record), write to `wiki/outputs/<descriptive-slug>.md`:

```yaml
---
title: "Q: The question asked"
query: "The original question"
created: "ISO timestamp"
classification: synthesize|record
sources_consulted: [slug1, slug2]
concepts_referenced: [concept-a, concept-b]
new_connections:                              # synthesize tier only
  - from: concept-a
    to: concept-b
    strength: strong|moderate|weak
    evidence: "one-line summary of why this connection exists"
---
```

**Connection strength** (synthesize tier only):

| Strength | Criteria | Graph impact |
|----------|----------|-------------|
| **strong** | Supported by 2+ independent sources with direct evidence | Added to `related` in both concept articles |
| **moderate** | Supported by 1 source with clear evidence, or 2+ sources with indirect evidence | Added to `related` in both concept articles with "(moderate)" note |
| **weak** | Inferred logically but not directly stated in any source | NOT added to concept articles — recorded in the output only, flagged for future confirmation |

This prevents the concept graph from accumulating speculative connections. Only strong and moderate connections update the graph. Weak connections are preserved in outputs for future validation — if a later source confirms a weak connection, `vault compile` or `vault lint` can upgrade it.

7. **Synthesize tier only**: After filing, update the affected concept articles:
   - Add new entries to `related` fields in both directions (strong and moderate only)
   - Add a brief note in the Source Evidence section referencing the output
   - Do NOT add more than 8 `related` entries per concept. If a concept already has 8, only add the new connection if its strength is equal to or greater than the weakest existing one (replace it). This caps graph density and keeps connections meaningful.

8. Update `wiki/index.md` recent outputs section if an output was filed.
9. Tell the user which tier was applied and why:
   - Synthesize: "Filed as synthesis — new connection: X ↔ Y (strong: supported by source-a and source-b)"
   - Record: "Filed for reference — comprehensive analysis across N sources"
   - Skip: "Quick lookup — not filed" or "Already covered in outputs/existing-slug.md"

**Post-query agent.md update** (after every query):

After composing the answer, update `.vault/agent.md`:

a. **Pattern reinforcement**: If a Query Pattern's suggested articles matched what was actually useful, increment its hit count.
b. **Pattern expansion**: If useful articles were not predicted by any pattern, update the closest matching pattern or create a new one (if under 10 slots).
c. **Pattern decay**: If a pattern's suggested articles were read but not useful, decrement its hit count. At 0 hits, evict the pattern.
d. **Cluster discovery**: If 2+ concepts were co-accessed and don't already share a cluster, create or merge into a cluster (if under 8 slots).
e. **Source signal update**: Increment cited count for any source whose summary or raw content contributed to the answer.
f. **Correction logging**: If agent.md routing led to a wrong path (Claude had to discard and re-route), log the correction (max 5, FIFO).
g. **Stats update**: Increment `total_queries`. If no Tier 3 reads were needed, increment `cache_hits`. Otherwise increment `tier3_fallbacks`.
h. **Decay check**: Every 20 queries (when `total_queries % 20 == 0`), divide all hit counts by 2 (integer division). This implements exponential decay — recent patterns outweigh old ones.
i. **Eviction**: If any section is at capacity and a new entry is needed, evict the entry with lowest hit/cited count. If tied, evict the oldest.

Write the updated `.vault/agent.md`.

**3-tier routing strategy:**
- Tier 1 (always): `wiki/index.md` — scan for relevance
- Tier 2 (on demand): `wiki/summaries/` and `wiki/concepts/` — read relevant articles
- Tier 3 (rarely): `raw/` — read full source only when needed

### vault process

Batch operation: ingest all Clippings, then compile all pending.

**Procedure:**

0. **Read `.vault/preferences.md`** — apply preferences to ingestion and compilation steps.
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

### vault cleanup

Audit and enrich all wiki articles. Unlike `vault lint` (which detects issues), cleanup actively **fixes** them.

**Procedure:**

0. **Read `.vault/preferences.md`** — apply domain context to quality judgments.
1. **Context building**: Read `wiki/index.md`, `wiki/_backlinks.json`, and scan all concept and summary articles. Map the full wiki structure.
2. **Per-article audit**: For each concept article, evaluate:

| Check | Bad sign | Action |
|:------|:---------|:-------|
| **Structure** | Facts appended chronologically, not organized by theme | Restructure around themes, not source order |
| **Length** | Over 80 lines | Split into sub-concept articles |
| **Length** | Under 15 lines (stub) | Enrich from raw sources or flag for more data |
| **Tone** | Peacock words, editorial voice, rhetorical questions | Rewrite to factual, Wikipedia-flat tone |
| **Quotes** | More than 2 direct quotes | Keep the 2 most impactful, convert others to paraphrases |
| **Wikilinks** | Missing connections to related concepts | Add `[[wikilinks]]` and update `related` fields |
| **Coherence** | "Here are 4 sources that mention X" | Rewrite to "X matters because Y, supported by..." |

3. **Split overstuffed articles**: If a concept article has 3+ distinct sub-topics in separate paragraphs, create dedicated concept articles for each. Update cross-references.
4. **Enrich stubs**: For articles under 15 lines, re-read the raw sources listed in the article's `sources` frontmatter. Extract additional detail to bring the article above the 15-line minimum.
5. **Fix broken wikilinks**: Scan for `[[links]]` pointing to non-existent articles. Either create the missing article or remove the broken link.
6. **Rebuild**: Regenerate `wiki/_backlinks.json` and `wiki/index.md`.
7. Report: "Cleanup complete: X articles restructured, Y stubs enriched, Z articles split, W broken links fixed."

### vault agent reset

Reset the learned retrieval intelligence. Use when agent.md has accumulated wrong patterns or the vault's domain has significantly changed.

1. Overwrite `.vault/agent.md` with the empty template (same as vault init creates).
2. Confirm to the user: "Agent reset. Retrieval patterns cleared. The agent will re-learn from your next queries."

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
