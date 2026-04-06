---
description: Answer a question grounded in vault knowledge
argument-hint: <question>
---

Follow the **vault-operations** skill's query procedure. The question is provided in `$ARGUMENTS`.

This includes:
1. Agent-directed pre-routing via `.vault/agent.md`
2. 3-tier classification of the question
3. Grounded retrieval and answer generation
4. Post-query update to `.vault/agent.md` with learned routing intelligence
