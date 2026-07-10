Before running a helper, set `KV_PLUGIN_ROOT` to `CLAUDE_PLUGIN_ROOT` when available; otherwise resolve the absolute plugin directory two levels above the parent `skills/knowledge-vault/SKILL.md`. Substitute that absolute path in each command.

## Procedure

0. Read `.vault/preferences.md` only if not already read in this session.
1. **Context building**: Read `wiki/index.md`, `wiki/_backlinks.json`, and scan all concept and summary articles. Map the full wiki structure.
2. **Per-article audit** -- for each concept article, evaluate:

| Check | Bad sign | Action |
|:------|:---------|:-------|
| Structure | Facts appended chronologically, not by theme | Restructure around themes |
| Length | Over 80 lines | Split into sub-concept articles |
| Length | Under 15 lines (stub) | Enrich from raw sources or flag |
| Tone | Peacock words, editorial voice, rhetorical questions | Rewrite to factual, Wikipedia-flat tone |
| Quotes | More than 2 direct quotes | Keep 2 most impactful, paraphrase rest |
| Wikilinks | Missing connections to related concepts | Add `[[wikilinks]]` and update `related` |
| Coherence | "Here are 4 sources that mention X" | Rewrite to "X matters because Y, supported by..." |

3. **Split overstuffed**: If 3+ distinct sub-topics in separate paragraphs, create dedicated concept articles. Update cross-references.
4. **Enrich stubs**: For articles under 15 lines, re-read raw sources in `sources` frontmatter. Extract detail to reach 15+ lines.
5. **Fix broken wikilinks**: `[[links]]` to non-existent articles -- create the missing article or remove the link.
6. **Rebuild** (via script — no need to re-read every file):
   ```bash
   bash "${KV_PLUGIN_ROOT}/scripts/rebuild-index.sh"
   ```

7. **Backfill missing originals** (v2.3 → v2.4 migration; opt-in, re-runnable):

   v2.4 introduced `.vault/originals/` for preserved source PDFs and `raw/<slug>.tree.json` PageIndex sidecars. Items ingested under v2.3 don't have either. This step opportunistically recovers them.

   a. **Scan candidates**:
      ```bash
      bash "${KV_PLUGIN_ROOT}/scripts/backfill-candidates.sh" .vault
      ```
      Returns `{categorized: {from_zotero, from_doi, from_url, unrecoverable}, counts, total_missing}`.

   b. If `total_missing == 0`: report "All raw items already have preserved originals. Nothing to backfill." and skip the rest of this step.

   c. **Present findings** in a compact table:
      ```
      Items missing original_path: <total_missing>
        from Zotero (re-fetch via MCP):    <count>
        from DOI (Unpaywall / Sci-Hub):    <count>
        from URL (direct download):        <count>
        unrecoverable (no source):         <count>
      ```
      Then ask: `Backfill which? (all / zotero-only / doi-only / url-only / pick / no)`. Treat any clearly negative reply as `no` and skip.

   d. **For each candidate selected**, recover the PDF using the appropriate method:
      - **`from_zotero`**: use the stored `zotero_key` to locate an actual local PDF attachment and copy it to `/tmp/kv-backfill-<slug>.pdf`. Extracted text is not a PDF and must never be saved with a `.pdf` extension. If no attachment is available, record `status: "no-pdf-found"` and skip.
      - **`from_doi`**: follow the enrich-references logic — try Unpaywall first (if `UNPAYWALL_EMAIL` is set), then Sci-Hub (if the marker and MCP tools are present). Save the PDF to `/tmp/kv-backfill-<slug>.pdf`.
      - **`from_url`**: `curl -L -o /tmp/kv-backfill-<slug>.pdf "<source>"` (permission prompt). Verify the response is actually a PDF (`file /tmp/kv-backfill-<slug>.pdf | grep -q PDF`). If not (login wall, captcha, etc.), record `status: "url-returned-non-pdf"` and skip.

   e. **Preserve, build tree, update frontmatter** (same flow regardless of recovery method). First verify every recovered file with `file /tmp/kv-backfill-<slug>.pdf | grep -q PDF`; if validation fails, record `status: "recovered-non-pdf"` and skip. Otherwise:
      ```bash
      mkdir -p .vault/originals
      mv /tmp/kv-backfill-<slug>.pdf .vault/originals/<slug>.pdf
      bash "${KV_PLUGIN_ROOT}/scripts/update-frontmatter.sh" \
        .vault/raw/<slug>.md \
        original_path=originals/<slug>.pdf
      ```
      **If PageIndex is set up** (dependencies and a supported model credential are available):
      ```bash
      bash "${KV_PLUGIN_ROOT}/scripts/build-tree.sh" .vault/originals/<slug>.pdf <slug> .vault
      ```
      On tree success: `update-frontmatter.sh ... has_tree=true tree_path=<slug>.tree.json`.
      On tree failure or PageIndex absent: `update-frontmatter.sh ... has_tree=false`. Don't touch the markdown body.

   f. **Important — preserve the existing slug**. Don't rename the file even if the slug is title-based (v2.3 style). Renaming would break every `[[wikilink]]` in `wiki/concepts/` and `wiki/summaries/` that references it. New ingests will use the v2.4 bibliographic slug; backfilled v2.3 items keep their original title-based slug. Slug heterogeneity is acceptable.

   g. **Don't replace the markdown body**. The v2.3 condensed body stays as-is; the tree.json sidecar is the new artifact. Wiki summaries that already cite the body keep working.

   h. **Final tally**:
      ```
      Backfill summary:
        Originals preserved:       <N>
        Trees built:               <T>
        Recovery failed:           <F>  (no PDF found / non-PDF response)
        Skipped (unrecoverable):   <U>
      ```
      List the failed slugs with their recovery method so the user can investigate manually.

8. Report: "Cleanup complete: X articles restructured, Y stubs enriched, Z articles split, W broken links fixed, B originals backfilled."

**Writing quality**: Only read `${KV_PLUGIN_ROOT}/skills/knowledge-vault/references/writing-rules.md` if not already read in this session.

**Context note**: Report only summary counts. Do not echo full article contents back to the user.
