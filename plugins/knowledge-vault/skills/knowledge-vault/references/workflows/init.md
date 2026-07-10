Before running a helper, set `KV_PLUGIN_ROOT` to `CLAUDE_PLUGIN_ROOT` when available; otherwise resolve the absolute plugin directory two levels above the parent `skills/knowledge-vault/SKILL.md`. Substitute that absolute path in each command.

## Procedure

1. Run: `bash "${KV_PLUGIN_ROOT}/scripts/init.sh"`
   - Creates `.vault/` and appends concise project guidance to `CLAUDE.md` and `AGENTS.md`.
   - Safe to rerun: an existing vault is left intact while missing guidance is repaired.

2. **Interview the user** for `.vault/preferences.md`. Ask one at a time; skip questions obvious from project context. If user says "skip" or wants defaults, generate sensible preferences from project context.

   a. **Domain**: "What domain is this vault for?" (e.g., ML research, biomedical science, web development, general)
   b. **Source types**: "What sources will you mainly use?" (papers, articles, code repos, meeting notes, web clips)
   c. **Priority rules**: "Any priority for sources?" (e.g., peer-reviewed over blog posts, recent over old)
   d. **Concept detail**: "How granular should concepts be?" (broad / balanced / granular)
   e. **Compilation focus**: "Any special instructions for summarization?" (e.g., always extract methodology, focus on clinical relevance)

3. Write `.vault/preferences.md`:

   ```yaml
   ---
   title: Vault Preferences
   updated: "ISO timestamp"
   ---

   ## Domain
   [from interview]

   ## Source Priority
   [ranked list]

   ## Concept Granularity
   [broad | balanced | granular]

   ## Compilation Focus
   [specific instructions]

   ## Custom Rules
   [any additional preferences]
   ```

4. Confirm vault is ready.
5. Suggest opening `.vault/` in Obsidian for visual navigation.
6. Suggest configuring research sources only if the user needs academic search or Zotero import.
