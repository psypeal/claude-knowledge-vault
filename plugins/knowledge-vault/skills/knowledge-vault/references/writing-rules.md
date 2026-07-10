# Writing Quality Rules

Reference document for vault compile and vault cleanup operations. These rules apply to all summaries and concept articles.

## Tone and Voice

- **Tone**: Write flat, factual, precise. State what the source found. Let data imply significance.
- **Avoid**: Peacock words ("groundbreaking", "revolutionary", "profound"), editorial voice ("interestingly", "importantly"), rhetorical questions, qualifiers ("truly", "deeply", "genuine").
- **Do**: Lead with the key finding. One claim per sentence. Short sentences. Simple past/present tense. Replace adjectives with specifics (numbers, dates, methods).

## Quote Discipline

Maximum 2 direct quotes per article. Choose the most impactful. Convert excess quotes to paraphrases.

## Anti-Cramming Rule

If a concept article develops multiple distinct sub-topics (3+ paragraphs on different aspects), split into separate concept articles. Resist the gravitational pull of existing articles -- create new pages rather than overstuffing.

## Anti-Thinning Rule

Creating articles is not the win; enriching them is. A stub with 2 vague sentences when 4 sources mention the topic is a failure. Every article must have real substance.

## Length Targets

| Article type | Target lines |
|:-------------|:-------------|
| Concept (1-2 sources) | 20-40 |
| Concept (3+ sources) | 40-80 |
| Summary | 30-60 |
| Output (query result) | 20-50 |
| Minimum (anything) | 15 |

## Quality Checkpoints

During batch compile of 5+ sources, pause after every 5 compiled sources and audit:

1. Rebuild `wiki/_backlinks.json` by scanning all `[[wikilinks]]` across articles.
2. Check for zero new concept articles -- if none were created, compilation is likely cramming.
3. Re-read the 3 most-updated concept articles. Verify:
   - Theme-based organization (not just appended facts)
   - Cross-article connections via wikilinks
   - Coherent narrative (not a chronological dump)
4. Flag concept articles exceeding 80 lines for potential splitting.

## Structure by Source Type

Different source types call for different article structures:

| Source type | Structure emphasis |
|:-----------|:------------------|
| paper | Methods -> Findings -> Implications |
| article | Thesis -> Evidence -> Relevance |
| repo | Architecture -> Key components -> Usage |
| meeting | Decisions -> Action items -> Context |
| dataset | Variables -> Coverage -> Limitations |
