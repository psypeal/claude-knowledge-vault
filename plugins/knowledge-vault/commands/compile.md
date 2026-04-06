---
description: Compile pending sources into wiki articles
argument-hint: "[source-slug]"
---

## Procedure

If `$ARGUMENTS` names a specific source slug, compile only that source. Otherwise compile all pending.

0. Read `.vault/preferences.md` — apply domain, priority, granularity, and compilation focus.
1. Read `.vault/raw/.manifest.json`. Identify entries where `compiled: false`.
2. **Plan phase**: For each pending source, read the raw file and produce a compilation plan:
   - Which concepts to create vs update
   - Key evidence to extract
   - Cross-references to add
   Group by concept — if multiple sources touch the same concept, merge updates.
3. **Execute phase**: Work through the plan:
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
4. **Mark compiled** (via script — no need to re-read raw files):
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/update-frontmatter.sh" .vault/raw/<slug>.md compiled=true
   ```
   Repeat for each compiled source.
5. **Rebuild index + backlinks + state** (via script — no need to read every file):
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/rebuild-index.sh"
   ```
6. **Update agent.md**: For each compiled source, add/update Source Signals entry (cited: 0, topic domains). Increment `vault_stats.total_compiles`.

**Concept slugs**: lowercase, hyphens, max 60 chars.

**Writing quality**: Read `${CLAUDE_PLUGIN_ROOT}/skills/vault-operations/references/writing-rules.md` for tone, length targets, anti-cramming/anti-thinning, and quality checkpoints.
