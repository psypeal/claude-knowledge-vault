---
description: Compile pending sources into wiki articles
argument-hint: "[source-slug]"
---

Your final response MUST be terse: "Compiled N sources, M concepts created/updated." or "Nothing pending." Do not echo file contents.

## Procedure

If `$ARGUMENTS` names a specific source slug, compile only that source. Otherwise compile all pending.

1. Read `.vault/raw/.manifest.json`. Identify entries where `compiled: false`.
   **If zero entries are pending: respond "Nothing pending — all sources already compiled." and STOP. Do not read any files, do not call any scripts.**

> **Batch mode** (2+ pending sources): read all raw sources first, output a numbered plan listing concepts to create/update, then execute writes in a single pass.

2. **Plan phase**: Read each pending raw source. For each, note concepts to create/update and evidence to extract. If batch, output: "Plan: [list concepts and which sources feed them]". Merge overlapping concept work.
3. **Execute phase**: Process each unique concept ONCE across all sources.
   a. Write summaries (`wiki/summaries/<slug>.md`, 200-500 words):
      ```yaml
      ---
      title: "Summary: Original Title"
      source_file: "raw/the-slug.md"
      source_type: paper
      compiled: "ISO timestamp"
      concepts_extracted: [concept-a, concept-b]
      word_count: 350
      ---
      ```
   b. For each UNIQUE concept, read the concept file ONCE (if existing), apply ALL updates, write ONCE.
   c. Cross-reference: update `related` fields. Use `[[wikilinks]]` in bodies. Do NOT read `_backlinks.json` — the script handles that.
4. **Mark compiled** — call BOTH scripts for EACH compiled source slug individually:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/update-frontmatter.sh" .vault/raw/SOURCE1.md compiled=true
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/update-manifest.sh" SOURCE1 compiled=true
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/update-frontmatter.sh" .vault/raw/SOURCE2.md compiled=true
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/update-manifest.sh" SOURCE2 compiled=true
   ```
   One pair of calls per source. Do NOT batch multiple slugs into one call.
5. **Rebuild**:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/rebuild-index.sh"
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/update-state.sh" .vault last_compiled="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
   ```
6. **Update agent.md** ONLY if `agent.md` frontmatter shows `total_queries >= 3`. Add/update Source Signals. Increment `total_compiles`.

**Tone: flat, factual. Max 2 quotes per article. Split if 3+ sub-topics.**
