---
name: knowledge-vault
description: Use when the user wants to create, add to, search, compile, inspect, repair, or configure a local `.vault/` knowledge base.
---

Choose one workflow and read only its reference before acting. If the request spans several operations, run them in dependency order. Treat the relevant part of the user's request as `$ARGUMENTS` wherever a workflow uses that placeholder.

If `.vault/` is missing, only initialize may proceed; offer initialization before other workflows. For scripts, follow the selected workflow's `KV_PLUGIN_ROOT` rule and never rely on the current working directory to locate plugin files.

| Intent | Workflow |
|---|---|
| Create a vault | [`references/workflows/init.md`](references/workflows/init.md) |
| Add a URL, file, PDF, or note | [`references/workflows/ingest.md`](references/workflows/ingest.md) |
| Import from Zotero | [`references/workflows/ingest-zotero.md`](references/workflows/ingest-zotero.md) |
| Search academic sources | [`references/workflows/collect.md`](references/workflows/collect.md) |
| Attach missing full text | [`references/workflows/enrich-references.md`](references/workflows/enrich-references.md) |
| Compile sources | [`references/workflows/compile.md`](references/workflows/compile.md) |
| Ask the vault | [`references/workflows/query.md`](references/workflows/query.md) |
| Process inbox and clippings | [`references/workflows/process.md`](references/workflows/process.md) |
| Validate or repair | [`references/workflows/lint.md`](references/workflows/lint.md), then [`references/workflows/cleanup.md`](references/workflows/cleanup.md) if fixes are requested |
| Configure research sources | [`references/workflows/setup-sources.md`](references/workflows/setup-sources.md) |
| Show state | [`references/workflows/status.md`](references/workflows/status.md) |
| Clear retrieval hints | [`references/workflows/agent-reset.md`](references/workflows/agent-reset.md) |
