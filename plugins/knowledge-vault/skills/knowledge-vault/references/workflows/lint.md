## Procedure

**Step 1 — Automated checks (via script, no tokens):**

```bash
<python> "${KV_PLUGIN_ROOT}/scripts/kv.py" lint
```

This checks manifest/raw/summary consistency, malformed state, stale concepts, missing links, orphaned files, thin articles, duplicate aliases, and original/tree integrity. A critical integrity error returns exit code 2 but still prints structured JSON; save that output and continue the report.

Check 9a flags raw items whose `original_path:` points to a missing file, and orphan files in `originals/` without a matching `raw/<slug>.md`. Check 9b flags items with `has_tree: true` whose `tree.json` is missing or invalid.

**Step 2 — Model checks (only if vault has 5+ concepts):**

Only read articles for these two checks if `.vault/wiki/.state.json` shows `concept_count >= 5`. Otherwise skip and report "Vault too small for contradiction/gap checks."

- **Check 1 (Contradictions)**: Read the 5 most-connected concepts (from `.vault/wiki/_backlinks.json`; pick slugs with most backlinks). Look for conflicting claims. Cite both sources.
- **Check 7 (Gap analysis)**: From the `.vault/wiki/index.md` concept table only, suggest 1-3 missing topics that would strengthen connections.

**Step 3 — Write report:**

Combine script output and model checks into `.vault/wiki/outputs/lint-YYYY-MM-DD.md`. Run:

```bash
<python> "${KV_PLUGIN_ROOT}/scripts/kv.py" rebuild
<python> "${KV_PLUGIN_ROOT}/scripts/kv.py" update-state .vault last_lint=<ISO-UTC-timestamp>
```

Print summary: "Vault lint: X critical, Y warnings, Z suggestions." Keep output terse — do not echo full article contents.
