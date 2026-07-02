---
description: Initialize a knowledge vault in the current project
---

## Procedure

1. Run: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/init.sh"`
   - Creates `.vault/` with empty structure and appends instructions to CLAUDE.md.
   - **If the script reports "Vault already exists" (exit 1): STOP.** Do not re-run the interview or overwrite the existing `.vault/preferences.md`. Tell the user the vault is already initialized and suggest `/knowledge-vault:status` instead.

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
6. Suggest running `/knowledge-vault:setup-sources` to configure research MCP servers.
