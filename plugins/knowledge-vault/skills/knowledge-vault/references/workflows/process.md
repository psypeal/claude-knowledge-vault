# Process Inbox

## Procedure

1. Read `.vault/preferences.md` if present.
2. Scan `.vault/inbox/` and `.vault/Clippings/` for Markdown, HTML, PDF, and text files. Ignore hidden files and directories.
3. For each item, follow the ingest workflow with these differences:
   - Use a title-based slug for Markdown and HTML clippings.
   - For PDFs, infer author or organization, year, keyword, and document type from metadata or first-page text.
   - Put the inbox file's absolute path in the structured ingest request under `original.path`.
   - Set `original.mode` to `move`. The transactional CLI copies and validates the artifact first, commits the raw file, manifest, and index, and only then removes the inbox file.
   - Never move or delete an inbox item before `kv.py ingest` reports success.
4. If PageIndex is ready and more than three PDFs are queued, report the count and obtain confirmation before incurring model-backed tree-building work. A declined tree batch still uses normal condensed ingestion.
5. After all successful ingests, follow the compile workflow once for the complete pending batch.

Report: `Processed N clippings, M PDFs (T trees built), compiled X sources, extracted K concepts.` Omit zero-valued clauses and list any input left in place after a failed ingest.
