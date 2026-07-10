Before running a helper, set `KV_PLUGIN_ROOT` to `CLAUDE_PLUGIN_ROOT` when available; otherwise resolve the absolute plugin directory two levels above the parent `skills/knowledge-vault/SKILL.md`. Substitute that absolute path in each command.

## Procedure

The source is provided in `$ARGUMENTS`. Accept: URL, file path, pasted text, or MCP tool output.

1. **Determine source type**:
   - URL → fetch with the host's web tool, set `type: clip` or `type: article`
   - URL ending in `.pdf` or returning `application/pdf` → set `type: paper` (or `report`/`manual`/`filing`/`guideline` if the content is institutional)
   - PubMed/Scholar MCP result → set `type: paper`
   - PDF file path → set `type: paper` (or `report`/`manual`/etc. if institutional)
   - Pasted text → set `type: notes`
   - File path (other) → read the file, infer type from context

2. **Derive a bibliographic slug**.
   - For `type: paper`: `<first-author-lastname>-<year>-<keyword>` (e.g., `vaswani-2017-attention`).
   - For `type: report` / `manual` / `filing` / `guideline`: `<org-abbrev>-<year>-<keyword>` (e.g., `who-2023-tuberculosis`, `fda-2024-bioequivalence`). Use your judgment for org abbreviations (`World Health Organization` → `who`).
   - For `type: article` / `repo` / `dataset` / `meeting` / `notes` / `clip`: title-based slug (lowercase, hyphens, max 60 chars), as in v2.3.

   **Metadata extraction chain** (use the first that yields author/org + year + keyword):
   1. Source already provides structured metadata (PubMed/Scholar MCP, DOI lookup) → use directly.
   2. Source URL has a DOI in path → query Crossref `https://api.crossref.org/works/<doi>` with the host's web tool.
   3. Source is a PDF and PageIndex is set up → run tree-build first; the resulting `tree.json` carries a `doc_description` with title/authors info.
   4. Source is a PDF, PageIndex unavailable → run `bash "${KV_PLUGIN_ROOT}/scripts/extract-metadata.sh" <pdf>` (returns first-page text); read it and extract author/org + year + 1-2-word keyword.
   5. All else fails → fall back to title-based slug. Set frontmatter `slug_source: title-fallback` so the user can rename later.

   Then sanitize and disambiguate:
   ```bash
   SLUG=$(bash "${KV_PLUGIN_ROOT}/scripts/derive-slug.sh" "<entity>" "<year>" "<keyword>" .vault)
   ```

3. **Preserve the original artifact** (only when there *is* one — text input has no original file):
   - PDF: download/copy to `.vault/originals/<slug>.pdf`.
   - HTML/web: save the raw HTML (or markdown if Web Clipper) to `.vault/originals/<slug>.html` (or `.md`).
   - Skip when the source is pasted text or notes — there's no original to preserve.

4. **Build tree** (only for PDF originals when PageIndex is set up):
   ```bash
   bash "${KV_PLUGIN_ROOT}/scripts/build-tree.sh" .vault/originals/<slug>.pdf <slug> .vault
   ```
   - On success (`exit 0`): set `has_tree: true` and `tree_path: <slug>.tree.json`. Render the body via `render-tree-outline.sh`.
   - On failure (or PageIndex unavailable): set `has_tree: false` and proceed to step 5's condense.

5. **Condense content** (token-efficiency step — used when no tree was built):

   **If the fetched content is 1000+ words AND the source is a URL, MCP result, or long pasted text** — produce a structured extraction instead of storing the full text:

   ```markdown
   ## Metadata
   - Authors: ...
   - Journal/Source: ...
   - Year: ...
   - DOI: ...

   ## Abstract
   [Original abstract if available, 200-300 words]

   ## Key Findings
   [Assistant-extracted, 200-400 words structured as bullet points]

   ## Methods
   [Brief methodology summary, 100-200 words]

   ## Quantitative Data
   [Extracted key statistics: HRs, CIs, p-values, sample sizes, effect sizes]
   ```

   This caps raw files at ~800-1200 words regardless of source length. The original source URL is preserved in the `source:` field for re-fetching if full text is ever needed.

   **Skip condensation** (store full content as-is) when:
   - The content is short (<1000 words)
   - The source is meeting notes (`type: notes` and contextually brief)
   - The user explicitly says "store full text"
   - A tree was already built in step 4 (the tree-derived outline replaces the flat condense)

6. **Run**: `bash "${KV_PLUGIN_ROOT}/scripts/ingest.sh" "<slug>" "<title>" "<type>" [tags...]` to create the raw file skeleton.

7. **Fill content + frontmatter**: Write the body (tree outline from step 4 or condensed from step 5) into `raw/<slug>.md` with the host's file-editing tools. Then run `update-frontmatter.sh` to record:
   - `source:` (URL if applicable)
   - `original_path: originals/<slug>.<ext>` (if step 3 preserved one)
   - `original_filename:` (incoming filename, for provenance)
   - `has_tree: true|false`
   - `tree_path: <slug>.tree.json` (only when has_tree=true)
   - `pages: <N>` (when known)

8. **Update index** (via script — no need to read index.md):
   ```bash
   bash "${KV_PLUGIN_ROOT}/scripts/index-append.sh" "<slug>" "<type>"
   ```

**Context note**: Report only: "Ingested <title> as raw/<slug>.md" plus, when applicable, "tree built (N pages)". Do not echo file contents.
