# Mutation Plan

Apply in order. After each, re-run relevant tests. Keep if score improves, discard if not.

## M1: Query — explicit file block-list
Target: commands/query.md
Change: Add "Do NOT read: preferences.md, agent.md, agent-update-rules.md, writing-rules.md, _backlinks.json, .manifest.json, .state.json"
Tests: query-simple, query-cross, query-missing

## M2: Compile — remove preferences.md read
Target: commands/compile.md
Change: Remove step 0 (preferences.md read). Inline domain hint: "Follow user preferences from VAULT-CLAUDE.md context."
Tests: compile-single, compile-batch, compile-empty

## M3: Ingest — reinforce terse response at top
Target: commands/ingest.md
Change: Add at top of procedure: "Your final response MUST be a single sentence: 'Ingested <title> as raw/<slug>.md'. Nothing else."
Tests: ingest-url, ingest-notes, ingest-long, ingest-special

## M4: Query — move "when to do more" to reference file
Target: commands/query.md
Change: Replace "When to do more" section with: "If user says 'file it' or 3+ queries this session, read ${CLAUDE_PLUGIN_ROOT}/skills/knowledge-vault/references/query-extensions.md"
Tests: query-simple, query-cross, query-missing

## M5: Compile — gate agent.md update on query threshold
Target: commands/compile.md
Change: Step 6 becomes: "Update agent.md ONLY if agent.md frontmatter shows total_queries >= 3."
Tests: compile-single, compile-batch

## M6: Query — cap raw-file reads at 1
Target: commands/query.md
Change: Add: "Read at most 1 raw file. Prefer to qualify your answer with 'based on the summary' rather than reading raw sources."
Tests: query-simple, query-cross

## M7: Compile — inline 3 critical writing rules
Target: commands/compile.md
Change: Replace writing-rules.md reference with inline: "Tone: flat, factual. Max 2 quotes per article. Split if 3+ sub-topics."
Tests: compile-single, compile-batch

## M8: Ingest — remove template matching
Target: commands/ingest.md
Change: Remove "If a matching template exists in .vault/templates/, use its structure."
Tests: ingest-url, ingest-notes

## M9: Compile — explicit no-backlinks instruction
Target: commands/compile.md
Change: Add: "Do NOT read _backlinks.json. The rebuild-index.sh script handles backlinks."
Tests: compile-single, compile-batch

## M10: Ingest — externalize condensation template
Target: commands/ingest.md
Change: Replace inline condensation template with: "If 1000+ words, read ${CLAUDE_PLUGIN_ROOT}/skills/knowledge-vault/references/condensation-template.md and apply."
Tests: ingest-long
