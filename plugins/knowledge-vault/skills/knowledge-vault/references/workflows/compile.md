Your final response MUST be terse: "Compiled N sources, M concepts created/updated." or "Nothing pending." Do not echo file contents.

## Procedure

If `$ARGUMENTS` names a specific source slug, compile only that source. Otherwise compile all pending.

1. Read `.vault/raw/.manifest.json`. Identify entries where `compiled: false`.
   **If zero entries are pending: respond "Nothing pending — all sources already compiled." and STOP. Do not read any files, do not call any scripts.**

> **Batch mode** (2+ pending sources): read all raw sources first, output a numbered plan listing concepts to create/update, then execute writes in a single pass.

2. **Plan phase**: Read each pending raw source. For each, note concepts to create/update and evidence to extract. If batch, output: "Plan: [list concepts and which sources feed them]". Merge overlapping concept work.
3. **Execute phase**: Process each unique concept ONCE across all sources.
   a. Write summaries (`.vault/wiki/summaries/<slug>.md`, 200-500 words):
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
   b. For each UNIQUE concept under `.vault/wiki/concepts/`, read the file ONCE (if existing), apply ALL updates, and write ONCE.
   c. Cross-reference: update `related` fields. Use `[[wikilinks]]` in bodies. Do NOT read `.vault/wiki/_backlinks.json`; the script handles that.
4. **Mark compiled** — after writing each summary, atomically update its raw file and manifest entry:
   ```text
   <python> "${KV_PLUGIN_ROOT}/scripts/kv.py" mark-compiled SOURCE1
   <python> "${KV_PLUGIN_ROOT}/scripts/kv.py" mark-compiled SOURCE2
   ```
   Call it once per source. It refuses to mark an item compiled when its summary file is missing.
5. **Rebuild**:
   ```bash
   <python> "${KV_PLUGIN_ROOT}/scripts/kv.py" rebuild
   <python> "${KV_PLUGIN_ROOT}/scripts/kv.py" update-state .vault last_compiled=<ISO-UTC-timestamp>
   ```
6. **Update `.vault/agent.md`** ONLY if its frontmatter shows `total_queries >= 3`. Add/update Source Signals. Increment `total_compiles`.

**Tone: flat, factual. Max 2 quotes per article. Split if 3+ sub-topics.**
