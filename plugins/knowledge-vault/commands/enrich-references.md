---
description: Find and attach fulltext for reference-only items via Unpaywall and/or Sci-Hub
argument-hint: "[slug or --all]"
---

## Procedure

Enriches raw items that have a DOI but no fulltext (`has_fulltext: false`), by finding a PDF via Unpaywall (open-access) and/or Sci-Hub (opt-in, per-project). Either source can be used on its own; when both are configured, Unpaywall is tried first and Sci-Hub handles what it misses.

`$ARGUMENTS` is either a specific slug, `--all` (default if empty), or empty (treated as `--all`).

### 1. Preflight

Determine which enrichment sources are available:

- **Unpaywall**: `UNPAYWALL_EMAIL` env var is set.
- **Sci-Hub**: the marker file `.vault/.scihub-enabled` exists AND an `mcp__scihub__*` tool (e.g. `mcp__scihub__search_scihub_by_doi`) is visible in this session. Both are set up by `/knowledge-vault:setup-sources` when the user opts in.

If **neither** is available, stop and tell the user:

> No enrichment source is configured. Set up at least one of:
> - **Unpaywall** (free, open-access only): `export UNPAYWALL_EMAIL=you@example.com` — add to `~/.bashrc` or `~/.zshrc` to persist. No signup required.
> - **Sci-Hub** (opt-in, per-project): run `/knowledge-vault:setup-sources` and select **Sci-Hub** when prompted.
>
> Then re-run this command.

Record which sources are available. If both, Unpaywall runs first per item and Sci-Hub handles the misses. If only one, that source handles every candidate directly.

### 2. Scan candidates

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/enrich-references.sh"
```

This returns `{"candidates": [{slug, doi, file, title, year}], "count": N}`.

- If `count == 0`: report "No reference-only items with DOI found. Nothing to enrich." and stop.
- If a specific slug was requested, filter candidates to that slug only; if no match, stop with "Not a candidate — either has_fulltext is already true, or the file has no DOI."

### 3. For each candidate, run this per-item flow

   **a. Query Unpaywall** (skip this step if Unpaywall is not available). Fetch `https://api.unpaywall.org/v2/<doi>?email=<UNPAYWALL_EMAIL>` using the WebFetch tool. Accept any of:
   - `is_oa: true` with `best_oa_location.url_for_pdf` → **direct PDF URL**
   - `is_oa: true` with `best_oa_location.url` → **landing page** (may still be PDF; try it)
   - `oa_locations[]` array → iterate; first with `url_for_pdf` wins.

   If no OA location: mark this item as "Unpaywall miss" and continue to step (c).

   **b. Fetch and extract.** If a PDF URL was found (from Unpaywall or Sci-Hub):
   - Download with `curl -L -o /tmp/kv-enrich-<slug>.pdf <url>` (permission prompt will appear). If the PDF came from a Sci-Hub MCP tool that already returned file bytes, use the local path directly.
   - Extract text: `pdftotext /tmp/kv-enrich-<slug>.pdf /tmp/kv-enrich-<slug>.txt`. If `pdftotext` is missing, tell the user once to install `poppler-utils` and continue with the remaining candidates using only metadata (skip extraction).
   - Read the text (first ~20k chars is usually plenty for a single paper).
   - **Condense** following the same structure as `/knowledge-vault:ingest-zotero` step 5g: Metadata / Abstract / Key Findings / Methods / Quantitative Data, capped at ~800-1200 words. Use Edit to replace the raw file's body (keep frontmatter intact).
   - Flip the flag:
     ```bash
     bash "${CLAUDE_PLUGIN_ROOT}/scripts/update-frontmatter.sh" <raw-file> has_fulltext=true
     ```
   - Clean up: `rm /tmp/kv-enrich-<slug>.pdf /tmp/kv-enrich-<slug>.txt`
   - If the item has a compiled summary already, mark it stale so `/knowledge-vault:compile` will regenerate:
     ```bash
     bash "${CLAUDE_PLUGIN_ROOT}/scripts/update-frontmatter.sh" <raw-file> compiled=false
     ```
   - Record result: `{slug, source: "unpaywall" | "scihub", status: "enriched"}`

   **c. Try Sci-Hub** (only if Sci-Hub is available, AND either Unpaywall is unavailable or Unpaywall missed on this DOI):
   - Call `mcp__scihub__search_scihub_by_doi` with the DOI. If it returns a PDF URL, use `mcp__scihub__download_scihub_pdf` to fetch it locally (or `curl -L -o /tmp/kv-enrich-<slug>.pdf <url>` if the tool only returns the URL).
   - If a PDF is obtained: run the same extract → condense → update flow as step (b), recording `source: "scihub"`.
   - If the DOI lookup fails or no PDF is returned: record `{slug, source: null, status: "no-pdf-found"}`.

   **d. If no source produced a PDF** (Unpaywall missed and Sci-Hub is unavailable, or both missed): record `{slug, source: null, status: "no-pdf-found"}`.

### 4. Final report

Print a summary table:

```
Enriched via Unpaywall: N
Enriched via Sci-Hub:    M
Still reference-only:    K
```

Omit source rows that are zero. List each still-reference-only slug with its DOI (so the user can check manually if they want).

### 5. Trailing tip (conditional)

- If `K > 0` AND Sci-Hub is NOT enabled AND Unpaywall IS enabled, print:
  > {K} items could not be enriched via Unpaywall. To add Sci-Hub as a fallback (opt-in, with legal considerations):
  > Run `/knowledge-vault:setup-sources` and select **Sci-Hub** when prompted. The disclaimer + per-project install runs there.

- If `K > 0` AND Unpaywall is NOT enabled AND Sci-Hub IS enabled, print:
  > {K} items could not be retrieved via Sci-Hub. To add Unpaywall as an additional (free, open-access) source:
  > `export UNPAYWALL_EMAIL=you@example.com` (add to `~/.bashrc` or `~/.zshrc` to persist), then re-run.

- If `N + M > 0`, print:
  > Tip: run `/knowledge-vault:compile` to regenerate summaries for the newly-enriched items.

## Notes

- **Either source works alone**: Unpaywall and Sci-Hub are peer sources, not strictly primary/fallback. If you've enabled only one, this command uses only that one. If both are available, Unpaywall goes first (free, OA-only, no legal questions), and Sci-Hub picks up the misses.
- **Network access required**: Unpaywall and PDF downloads hit the public web. The plugin itself does not host or mirror any paper content.
- **Non-destructive**: if any step fails for a given item, that item is left unchanged and the next one is attempted. The tally at the end reflects actual outcomes.
- **Zotero coexistence**: if the item was originally ingested from Zotero, Zotero still owns the canonical PDF (if any). This command only updates the vault's extracted-text body.
- **Re-runnable**: items already at `has_fulltext: true` are skipped by the scan. Safe to run repeatedly as you add new reference-only items.
- **Unpaywall coverage**: roughly 40-50% of DOIs have a discoverable OA version. Coverage is highest for biomedical and physics/CS literature.
