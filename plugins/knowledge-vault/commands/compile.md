---
description: Compile pending sources into wiki articles
argument-hint: "[source-slug]"
---

## Procedure

If `$ARGUMENTS` names a specific source slug, compile only that source. Otherwise compile all pending.

> **Batch mode** (2+ pending sources): read all raw sources first, build a merged compilation plan, then execute all writes in a single pass.

0. Read `.vault/preferences.md` — apply domain, priority, granularity, and compilation focus.
1. Read `.vault/raw/.manifest.json`. Identify entries where `compiled: false`.
2. **Plan phase**: Read ALL pending raw sources sequentially. For each, note concepts to create/update and evidence to extract. Then MERGE: if sources A and B both touch concept X, group those updates together.
   - Which concepts to create vs update
   - Key evidence to extract
   - Cross-references to add
3. **Execute phase**: Process each unique concept ONCE across all sources. Do not re-read a concept file that was already read for another source in this batch. Work through the plan:
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
   b. For each UNIQUE concept in the plan, read the concept file ONCE (if existing), apply ALL updates from ALL sources, write ONCE:
      ```yaml
      ---
      title: "Concept Name"
      aliases: [alt-name]
      created: "ISO timestamp"
      updated: "ISO timestamp"
      sources: [source-slug]
      related: [other-concept]
      ---
      ```
   c. Cross-reference: update `related` fields. Use `[[wikilinks]]` in bodies.
4. **Mark compiled** (via scripts — no need to re-read raw files):
   For each compiled source:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/update-frontmatter.sh" .vault/raw/<slug>.md compiled=true
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/update-manifest.sh" <slug> compiled=true
   ```
5. **Rebuild index + backlinks + state** (via script — no need to read every file):
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/rebuild-index.sh"
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/update-state.sh" .vault last_compiled="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
   ```
6. **Update agent.md**: For each compiled source, add/update Source Signals entry (cited: 0, topic domains). Increment `vault_stats.total_compiles`.

**Concept slugs**: lowercase, hyphens, max 60 chars.

**Writing quality**: Read `${CLAUDE_PLUGIN_ROOT}/skills/vault-operations/references/writing-rules.md` for tone, length targets, anti-cramming/anti-thinning, and quality checkpoints.
