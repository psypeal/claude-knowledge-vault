---
description: Batch ingest inbox + Clippings and compile all pending
---

## Procedure

0. Read `.vault/preferences.md` — apply preferences to ingestion and compilation.

1. **Scan inbox locations**:
   - `.vault/inbox/` and `.vault/Clippings/` for `.md` and `.html` files (Web Clipper drops).
   - `.vault/inbox/` for `.pdf` files (manual drops).

2. **For each Markdown / HTML clipping**:
   a. Read it. Extract title and metadata from YAML frontmatter (Obsidian Web Clipper format).
   b. Derive a slug from the title (title-based, as in v2.3 — clips are `type: clip` or `type: article`).
   c. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/ingest.sh" "<slug>" "<title>" "<type>"` — this creates the `raw/<slug>.md` skeleton AND registers the entry in `raw/.manifest.json` (required: `/compile` is manifest-driven; a raw file outside the manifest is never compiled).
   d. Edit `raw/<slug>.md` to fill the body with the clipping content, then `update-frontmatter.sh` to record `source:` (the clipped URL) and any extra clipper metadata.
   e. Move the original to `.vault/originals/<slug>.<ext>` if it's HTML (record `original_path:`); for clipper-converted markdown, treat the markdown itself as the original and skip the duplicate. Delete the inbox copy.
   f. `bash "${CLAUDE_PLUGIN_ROOT}/scripts/index-append.sh" "<slug>" "<type>"` (updates `wiki/index.md` only).

3. **For each PDF in inbox** — first, if PageIndex is set up and there are more than 3 PDFs, tell the user how many trees would be built (~30s-2min and a few cents of API cost each) and confirm before proceeding:
   a. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/extract-metadata.sh" <pdf>` to grab the first-page text.
   b. Read it; infer author/org + year + 1-2-word keyword. Decide `type` (paper / report / manual / filing / guideline).
   c. Derive the slug:
      ```bash
      SLUG=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/derive-slug.sh" "<entity>" "<year>" "<keyword>" .vault)
      ```
   d. Move (don't copy) the PDF to `.vault/originals/<slug>.pdf`.
   e. **If PageIndex is set up**:
      ```bash
      bash "${CLAUDE_PLUGIN_ROOT}/scripts/build-tree.sh" .vault/originals/<slug>.pdf <slug> .vault
      ```
      On success: render the body via `render-tree-outline.sh`. On failure: fall back to `pdftotext` + condense.
   f. Run `ingest.sh` to create the raw file skeleton, then Edit to fill the body, then `update-frontmatter.sh` to record `original_path`, `original_filename`, `has_tree`, `tree_path`, `pages`.
   g. `index-append.sh "<slug>" "<type>"`.

4. **Compile pass**: run the compile procedure (from `/knowledge-vault:compile`) on all pending sources in a single batch pass — do not compile one-by-one.

5. **Report**: "Processed N clippings, M PDFs (T trees built), compiled X sources, extracted K new concepts." Omit zero-rows.
