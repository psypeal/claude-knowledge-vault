---
name: knowledge-vault
description: Operate a local knowledge-base vault (.vault/ directory) within any project. This skill should be used when the user says "vault init", "vault ingest", "vault compile", "vault lint", "vault query", "vault process", "vault cleanup", "vault collect", "vault setup-sources", "vault status", "vault agent reset", "add to vault", "ask the vault", "check the vault", or references the .vault/ directory.
user-invocable: false
---

Route to the appropriate `/knowledge-vault:*` command:

| Trigger | Command |
|---------|---------|
| vault init | `/knowledge-vault:init` |
| vault ingest, add to vault | `/knowledge-vault:ingest` |
| vault compile | `/knowledge-vault:compile` |
| vault lint | `/knowledge-vault:lint` |
| vault query, ask the vault | `/knowledge-vault:query` |
| vault process | `/knowledge-vault:process` |
| vault status, check the vault | `/knowledge-vault:status` |
| vault cleanup | `/knowledge-vault:cleanup` |
| vault agent reset | `/knowledge-vault:agent-reset` |
| vault collect | `/knowledge-vault:collect` |
| vault setup-sources | `/knowledge-vault:setup-sources` |
