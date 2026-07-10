Before running a helper, set `KV_PLUGIN_ROOT` to `CLAUDE_PLUGIN_ROOT` when available; otherwise resolve the absolute plugin directory two levels above the parent `skills/knowledge-vault/SKILL.md`. Substitute that absolute path in each command.

## Procedure

0. Read `.vault/preferences.md` — apply preferences to ingestion and compilation.

1. **Scan inbox locations**:
   - `.vault/inbox/` and `.vault/Clippings/` for `.md` and `.html` files (Web Clipper drops).
   - `.vault/inbox/` for `.pdf` files (manual drops).

2. **For each Markdown / HTML clipping**:
   a. Read it. Extract title and metadata from YAML frontmatter (Obsidian Web Clipper format).
   b. Derive a slug from the title (title-based, as in v2.3 — clips are `type: clip` or `type: article`).
   c. Run `bash "${KV_PLUGIN_ROOT}/scripts/ingest.sh" "<slug>" "<title>" "<type>"`. This creates the raw skeleton and manifest entry; compile is manifest-driven.
   d. Fill `raw/<slug>.md` with the clipping body and update its `source` plus clipper metadata.
   e. Move the input artifact to `.vault/originals/<slug>.<ext>`, record `original_path`, and remove the inbox copy.
   f. Run `bash "${KV_PLUGIN_ROOT}/scripts/index-append.sh" "<slug>" "<type>"` to update only the wiki index.

3. **For each PDF in inbox**: if PageIndex is ready and more than three PDFs are queued, report the count and approximate per-file API work, then confirm before building the batch of trees.
   a. Run `bash "${KV_PLUGIN_ROOT}/scripts/extract-metadata.sh" <pdf>` to grab the first-page text.
   b. Read it; infer author/org + year + 1-2-word keyword. Decide `type` (paper / report / manual / filing / guideline).
   c. Derive the slug:
      ```bash
      SLUG=$(bash "${KV_PLUGIN_ROOT}/scripts/derive-slug.sh" "<entity>" "<year>" "<keyword>" .vault)
      ```
   d. Move (don't copy) the PDF to `.vault/originals/<slug>.pdf`.
   e. **If PageIndex is set up**:
      ```bash
      bash "${KV_PLUGIN_ROOT}/scripts/build-tree.sh" .vault/originals/<slug>.pdf <slug> .vault
      ```
      On success: render the body via `render-tree-outline.sh`. On failure: fall back to `pdftotext` + condense.
   f. Run `ingest.sh` to create the raw file and manifest entry, fill the body with the host's file-editing tools, then run `update-frontmatter.sh` to record `original_path`, `original_filename`, `has_tree`, `tree_path`, and `pages`.
   g. `index-append.sh "<slug>" "<type>"`.

4. **Compile pass**: follow the compile skill for all pending sources in one batch pass; do not compile one-by-one.

5. **Report**: "Processed N clippings, M PDFs (T trees built), compiled X sources, extracted K new concepts." Omit zero-rows.
