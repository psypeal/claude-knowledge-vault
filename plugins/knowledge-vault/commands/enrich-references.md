---
description: Find and attach fulltext for reference-only items via Unpaywall (and optionally Sci-Hub)
argument-hint: "[slug or --all]"
---

## Procedure

Enriches raw items that have a DOI but no fulltext (`has_fulltext: false`), by finding an open-access PDF via Unpaywall. An optional Sci-Hub fallback is available for users who have explicitly opted in.

`$ARGUMENTS` is either a specific slug, `--all` (default if empty), or empty (treated as `--all`).

### 1. Preflight

- Check that `UNPAYWALL_EMAIL` is set. If not, stop and tell the user:
  > Unpaywall requires an email for polite API use. Set it once:
  > `export UNPAYWALL_EMAIL=you@example.com` (add to `~/.bashrc` or `~/.zshrc` to persist)
  > Then re-run this command.

- Record whether Sci-Hub fallback is enabled for this vault: both conditions must hold —
  - The marker file `.vault/.scihub-enabled` exists (written by `/knowledge-vault:setup-scihub`)
  - An MCP tool matching `mcp__scihub__search_scihub_by_doi` or any `mcp__scihub__*` is visible in this session

### 2. Scan candidates

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/enrich-references.sh"
```

This returns `{"candidates": [{slug, doi, file, title, year}], "count": N}`.

- If `count == 0`: report "No reference-only items with DOI found. Nothing to enrich." and stop.
- If a specific slug was requested, filter candidates to that slug only; if no match, stop with "Not a candidate — either has_fulltext is already true, or the file has no DOI."

### 3. For each candidate, run this per-item flow

   **a. Query Unpaywall.** Fetch `https://api.unpaywall.org/v2/<doi>?email=<UNPAYWALL_EMAIL>` using the WebFetch tool. Accept any of:
   - `is_oa: true` with `best_oa_location.url_for_pdf` → **direct PDF URL**
   - `is_oa: true` with `best_oa_location.url` → **landing page** (may still be PDF; try it)
   - `oa_locations[]` array → iterate; first with `url_for_pdf` wins.

   If no OA location: mark this item as "Unpaywall miss" and continue to step (c) for Sci-Hub fallback.

   **b. Fetch and extract.** If a PDF URL was found:
   - Download with `curl -L -o /tmp/kv-enrich-<slug>.pdf <url>` (permission prompt will appear).
   - Extract text: `pdftotext /tmp/kv-enrich-<slug>.pdf /tmp/kv-enrich-<slug>.txt`. If `pdftotext` is missing, tell the user once to install `poppler-utils` and continue with the remaining candidates using only Unpaywall metadata (skip extraction).
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
   - Record result: `{slug, source: "unpaywall", status: "enriched"}`

   **c. Optional Sci-Hub fallback** (only if Unpaywall missed AND the Sci-Hub opt-in preflight passed):
   - Call `mcp__scihub__search_scihub_by_doi` with the DOI. If it returns a PDF URL, use `mcp__scihub__download_scihub_pdf` to fetch it locally (or `curl -L -o /tmp/kv-enrich-<slug>.pdf <url>` if the tool only returns the URL).
   - If a PDF is obtained: run the same extract → condense → update flow as step (b), but record `source: "scihub"`.
   - If the DOI lookup fails or no PDF is returned: record `{slug, source: null, status: "no-oa-found"}`.

   **d. If Sci-Hub is disabled AND Unpaywall missed**: record `{slug, source: null, status: "unpaywall-miss"}`.

### 4. Final report

Print a summary table:

```
Enriched via Unpaywall: N
Enriched via Sci-Hub:    M
Still reference-only:    K
```

List each still-reference-only slug with its DOI (so the user can check manually if they want).

### 5. Trailing tip (conditional)

- If `K > 0` AND Sci-Hub fallback was NOT enabled, print:
  > {K} items could not be enriched via Unpaywall. To add a Sci-Hub fallback (opt-in, with legal considerations):
  > `/knowledge-vault:setup-scihub`

- If `N + M > 0`, print:
  > Tip: run `/knowledge-vault:compile` to regenerate summaries for the newly-enriched items.

## Notes

- **Network access required**: Unpaywall and PDF downloads hit the public web. The plugin itself does not host or mirror any paper content.
- **Non-destructive**: if any step fails for a given item, that item is left unchanged and the next one is attempted. The tally at the end reflects actual outcomes.
- **Zotero coexistence**: if the item was originally ingested from Zotero, Zotero still owns the canonical PDF (if any). This command only updates the vault's extracted-text body.
- **Re-runnable**: items already at `has_fulltext: true` are skipped by the scan. Safe to run repeatedly as you add new reference-only items.
- **Unpaywall coverage**: roughly 40-50% of DOIs have a discoverable OA version. Coverage is highest for biomedical and physics/CS literature.
