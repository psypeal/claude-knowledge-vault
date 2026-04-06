---
description: Batch search academic databases and selectively ingest results
argument-hint: "<search-query> [--count N] [--since YYYY]"
---

Use the **vault-collector** agent. The search query is provided in `$ARGUMENTS`.

1. Read `.vault/sources.json` for configured research servers.
2. Search all enabled sources using the query.
3. Present a numbered results table to the user.
4. User picks which results to ingest.
5. Optionally compile ingested sources after selection.
