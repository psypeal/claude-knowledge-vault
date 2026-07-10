# Cleanup

## Procedure

0. Read `.vault/preferences.md` only if it has not already been read in this session.
1. Read `.vault/wiki/index.md`, `.vault/wiki/_backlinks.json`, and the articles under `.vault/wiki/concepts/` and `.vault/wiki/summaries/`. Map the wiki before editing it.
2. Audit each concept:

| Check | Bad sign | Action |
|---|---|---|
| Structure | Facts are appended chronologically | Restructure around themes |
| Length | More than 80 lines | Split distinct sub-concepts |
| Length | Fewer than 15 lines | Enrich from linked raw sources or flag |
| Tone | Editorial language or rhetorical questions | Rewrite in a flat factual tone |
| Quotes | More than two direct quotes | Keep at most two; paraphrase the rest |
| Links | Missing or broken `[[wikilinks]]` | Add supported links or remove broken ones |
| Coherence | Source-by-source list rather than synthesis | Organize around the concept and evidence |

3. Split articles with three or more distinct subtopics. Update cross-references.
4. Enrich stubs from the raw sources named in frontmatter. Do not add unsupported detail.
5. Repair broken wikilinks by creating a supported article or removing the link.
6. Rebuild generated indexes:

   ```text
   <python> "${KV_PLUGIN_ROOT}/scripts/kv.py" rebuild
   ```

7. Offer the backward-compatible original-file backfill only when legacy items need it:

   ```text
   <python> "${KV_PLUGIN_ROOT}/scripts/backfill_candidates.py" .vault
   ```

   If `total_missing` is zero, skip. Otherwise show counts for `from_zotero`, `from_doi`, `from_url`, and `unrecoverable`, then ask which recoverable categories to process.

8. Recover each approved PDF without putting source metadata in shell syntax:
   - **Zotero:** use the stored key to obtain a real local PDF attachment. Extracted text must not be labeled as PDF.
   - **DOI:** use the enrich-references source order: Unpaywall, then explicitly enabled Sci-Hub.
   - **URL:** write the source URL to `.vault/.staging/<slug>.download.json` and run the structured downloader exactly as documented in enrich-references.

   Every recovery method must produce a local file that passes `expected: "pdf"` validation. Login pages, captcha responses, and extracted text are failures.

9. Attach each validated recovery with `.vault/.staging/<slug>.attach.json`:

   ```json
   {
     "slug": "<slug>",
     "original": {
       "path": "<slug>.recovered.pdf",
       "mode": "move",
       "expected": "pdf",
       "filename": "incoming.pdf"
     },
     "frontmatter": {
       "has_tree": false
     }
   }
   ```

   Use an absolute path and `mode: copy` for an MCP or Zotero-owned file. Then run:

   ```text
   <python> "${KV_PLUGIN_ROOT}/scripts/kv.py" attach-original --request .vault/.staging/<slug>.attach.json --cleanup-request
   ```

   The command preserves the existing slug and body, validates the PDF, and rolls back the raw update if attachment fails.

10. When PageIndex is ready, optionally add a tree after attachment:

    ```text
    <python> "${KV_PLUGIN_ROOT}/scripts/build_tree.py" .vault/originals/<slug>.pdf <slug> .vault
    <python> "${KV_PLUGIN_ROOT}/scripts/kv.py" update-frontmatter .vault/raw/<slug>.md has_tree=true tree_path=<slug>.tree.json
    ```

    On failure, leave `has_tree: false`. Never rename a legacy slug or replace its existing condensed body during backfill.

11. Report cleanup counts plus originals preserved, trees built, failed recoveries, and unrecoverable items. List failed slugs with their attempted recovery method.

Read `${KV_PLUGIN_ROOT}/skills/knowledge-vault/references/writing-rules.md` only when writing or restructuring articles. Report summary counts, not full article contents.
