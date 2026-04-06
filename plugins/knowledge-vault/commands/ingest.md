---
description: Add a raw source to the vault
argument-hint: <url|text|filepath>
---

## Procedure

The source is provided in `$ARGUMENTS`. Accept: URL, file path, pasted text, or MCP tool output.

1. **Determine source type**:
   - URL -> fetch with WebFetch, set `type: clip` or `type: article`
   - PubMed/Scholar MCP result -> set `type: paper`
   - Pasted text -> set `type: notes`
   - File path -> read the file, infer type from context

2. **Generate slug** from the title: lowercase, hyphens for spaces, max 60 chars.

3. **Run**: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/ingest.sh" "<slug>" "<title>" "<type>" [tags...]`

4. **Fill content**: Write the content body into `raw/<slug>.md` using Edit tool. If a matching template exists in `.vault/templates/`, use its structure.

5. **Set source field**: If the source is a URL, set the `source:` field in the frontmatter.

6. **Update index** (via script — no need to read index.md):
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/index-append.sh" "<slug>" "<type>"
   ```
