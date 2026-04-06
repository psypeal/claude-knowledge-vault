---
description: Initialize a knowledge vault in the current project
---

Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/init.sh"` to scaffold the `.vault/` directory.

Then interview the user for their vault preferences following the **vault-operations** skill's initialization procedure. Write the results to `.vault/preferences.md`.

After setup:
1. Suggest opening `.vault/` in Obsidian for visual navigation.
2. Suggest running `/vault:setup-sources` to configure research MCP servers for academic collection.
