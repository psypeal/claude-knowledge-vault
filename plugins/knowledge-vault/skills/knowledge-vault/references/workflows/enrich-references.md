Before running a helper, set `KV_PLUGIN_ROOT` to `CLAUDE_PLUGIN_ROOT` when available; otherwise resolve the absolute plugin directory two levels above the parent `skills/knowledge-vault/SKILL.md`. Substitute that absolute path in each command.

## Procedure

Enriches DOI-based items without full text (`has_fulltext: false`) through Unpaywall and/or the optional Sci-Hub integration. Either source works alone; when both are configured, try Unpaywall first.

`$ARGUMENTS` is either a specific slug, `--all` (default if empty), or empty (treated as `--all`).

### 1. Preflight

Determine which enrichment sources are available:

- **Unpaywall**: `UNPAYWALL_EMAIL` env var is set.
- **Sci-Hub**: the marker file `.vault/.scihub-enabled` exists AND an `mcp__scihub__*` tool (for example, `mcp__scihub__search_scihub_by_doi`) is visible. Both are set up by setup-sources after the user opts in.

If **neither** is available, stop and tell the user:

> No enrichment source is configured. Set up at least one of:
> - **Unpaywall** (free, open-access only): `export UNPAYWALL_EMAIL=you@example.com` — add to `~/.bashrc` or `~/.zshrc` to persist. No signup required.
> - **Sci-Hub** (opt-in): run the setup-sources workflow and select **Sci-Hub**.
>
> Then re-run this workflow.

Record which sources are available. If both, Unpaywall runs first per item and Sci-Hub handles the misses. If only one, that source handles every candidate directly.

### 2. Scan candidates

```bash
bash "${KV_PLUGIN_ROOT}/scripts/enrich-references.sh"
```

This returns `{"candidates": [{slug, doi, file, title, year}], "count": N}`.

- If `count == 0`: report "No reference-only items with DOI found. Nothing to enrich." and stop.
- If a specific slug was requested, filter candidates to that slug only; if no match, stop with "Not a candidate — either has_fulltext is already true, or the file has no DOI."

### 3. For each candidate, run this per-item flow

   **a. Query Unpaywall** (skip if unavailable). Fetch `https://api.unpaywall.org/v2/<doi>?email=<UNPAYWALL_EMAIL>` with the host's web tool. Accept any of:
   - `is_oa: true` with `best_oa_location.url_for_pdf` → **direct PDF URL**
   - `is_oa: true` with `best_oa_location.url` → **landing page** (may still be PDF; try it)
   - `oa_locations[]` array → iterate; first with `url_for_pdf` wins.

   If no OA location: mark this item as "Unpaywall miss" and continue to step (c).

   **b. Fetch, preserve, and (if PageIndex is set up) tree-build.** If a PDF URL was found (from Unpaywall or Sci-Hub):
   - Download with `curl -L -o /tmp/kv-enrich-<slug>.pdf <url>` (permission prompt will appear). If the PDF came from a Sci-Hub MCP tool that already returned file bytes, use the local path directly.
   - **Preserve the original** under `.vault/originals/<slug>.pdf` (do NOT `rm` it after extraction). Today's slug for reference-only items is the existing one — keep it; rename-on-ingest is for the ingest path. Record the incoming filename in frontmatter as `original_filename:` for provenance, and set `original_path: originals/<slug>.pdf`.
   - **If PageIndex is set up** (dependencies and a supported model credential are available):
     ```bash
     bash "${KV_PLUGIN_ROOT}/scripts/build-tree.sh" .vault/originals/<slug>.pdf <slug> .vault
     ```
     - On success (`exit 0`): tree saved to `raw/<slug>.tree.json`. Render the body via:
       ```bash
       bash "${KV_PLUGIN_ROOT}/scripts/render-tree-outline.sh" .vault/raw/<slug>.tree.json
       ```
       Replace the raw file body with the rendered outline using the host's file-editing tools, preserving frontmatter. Set `has_tree: true` and `tree_path: <slug>.tree.json`.
     - On failure (any non-zero exit): set `has_tree: false`, log the failure, and proceed to flat-condense fallback below.
   - **Flat-condense fallback** (when PageIndex is not set up, or build-tree failed):
     - Extract text: `pdftotext /tmp/kv-enrich-<slug>.pdf /tmp/kv-enrich-<slug>.txt`. If `pdftotext` is missing, tell the user once to install `poppler-utils` and continue with the remaining candidates using only metadata.
     - Read the text (first ~20k chars is usually plenty for a single paper).
     - **Condense** following the ingest-zotero structure: Metadata / Abstract / Key Findings / Methods / Quantitative Data, capped at ~800-1200 words. Replace the raw body while preserving frontmatter.
   - Flip the fulltext flag and record paths:
     ```bash
     bash "${KV_PLUGIN_ROOT}/scripts/update-frontmatter.sh" <raw-file> has_fulltext=true original_path=originals/<slug>.pdf
     ```
   - Clean up the temp file: `rm -f /tmp/kv-enrich-<slug>.pdf /tmp/kv-enrich-<slug>.txt`. Keep the copy in `originals/`.
   - If the item has a compiled summary already, mark it stale so the compile workflow regenerates it:
     ```bash
     bash "${KV_PLUGIN_ROOT}/scripts/update-frontmatter.sh" <raw-file> compiled=false
     ```
   - Record result: `{slug, source: "unpaywall" | "scihub", status: "enriched", tree_built: true|false}`

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
Trees built (PageIndex): T
Still reference-only:    K
```

Omit rows that are zero. List each still-reference-only slug with its DOI (so the user can check manually if they want). The `Trees built` row is shown only when PageIndex is set up.

### 5. Trailing tip (conditional)

- If `K > 0` AND Sci-Hub is NOT enabled AND Unpaywall IS enabled, print:
  > {K} items could not be enriched via Unpaywall. To add Sci-Hub as a fallback (opt-in, with legal considerations):
  > Run setup-sources and select **Sci-Hub**. The disclosure and host-specific registration run there.

- If `K > 0` AND Unpaywall is NOT enabled AND Sci-Hub IS enabled, print:
  > {K} items could not be retrieved via Sci-Hub. To add Unpaywall as an additional (free, open-access) source:
  > `export UNPAYWALL_EMAIL=you@example.com` (add to `~/.bashrc` or `~/.zshrc` to persist), then re-run.

- If `N + M > 0`, print:
  > Tip: run compile to regenerate summaries for the enriched items.

## Notes

- **Either source works alone**: Unpaywall and Sci-Hub are peer sources, not strictly primary/fallback. If you've enabled only one, this command uses only that one. If both are available, Unpaywall goes first (free, OA-only, no legal questions), and Sci-Hub picks up the misses.
- **Network access required**: Unpaywall and PDF downloads hit the public web. The plugin itself does not host or mirror any paper content.
- **Non-destructive**: if any step fails for a given item, that item is left unchanged and the next one is attempted. The tally at the end reflects actual outcomes.
- **Originals are preserved**: every successfully fetched PDF lands at `.vault/originals/<slug>.pdf` for long-term audit/reading. The temporary `/tmp/kv-enrich-<slug>.pdf` is cleaned up.
- **PageIndex behavior is graceful**: if PageIndex isn't installed, this command works exactly as in v2.3 (flat condense). If it is installed but a tree build fails for a particular PDF, the item silently falls back to flat condense — `has_tree: false` records this so a future retry can rebuild.
- **Zotero coexistence**: if the item was originally ingested from Zotero, Zotero still owns the canonical PDF (if any). This command only updates the vault's extracted-text body.
- **Re-runnable**: items already at `has_fulltext: true` are skipped by the scan. Safe to run repeatedly as you add new reference-only items.
- **Unpaywall coverage**: roughly 40-50% of DOIs have a discoverable OA version. Coverage is highest for biomedical and physics/CS literature.
