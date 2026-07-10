# Initialize

1. Run:

   ```text
   <python> "${KV_PLUGIN_ROOT}/scripts/kv.py" init
   ```

   This creates `.vault/`, default preferences, templates, and concise guidance in `AGENTS.md` and `CLAUDE.md`. It also creates `.vault/.gitignore` so private vault contents are ignored by Git by default. Re-running it preserves vault data and repairs missing host guidance.
2. If the user already supplied a domain, source priority, concept granularity, or compilation focus, update `.vault/preferences.md` now. Otherwise retain the useful defaults; do not block initialization with an interview.
3. Report that the vault is ready. Mention that `<python> "${KV_PLUGIN_ROOT}/scripts/kv.py" init --track` removes the plugin's unchanged default ignore file and opts into version-controlling vault contents. Suggest Obsidian or research-source setup only when relevant.
