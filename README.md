<p align="center">
  <h1 align="center">Claude Knowledge Vault</h1>
  <p align="center">
    <strong>A local, LLM-powered knowledge base for any project.</strong>
    <br />
    Ingest sources. Compile a wiki. Query your knowledge. Browse in Obsidian.
  </p>
  <p align="center">
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License" /></a>
    <a href="https://docs.anthropic.com/en/docs/claude-code"><img src="https://img.shields.io/badge/Claude_Code-skill-blueviolet.svg" alt="Claude Code Skill" /></a>
    <a href="https://obsidian.md"><img src="https://img.shields.io/badge/Obsidian-compatible-7C3AED.svg" alt="Obsidian Compatible" /></a>
  </p>
</p>

<br />

> Built on ideas from [Andrej Karpathy's LLM knowledge base approach](https://x.com/karpathy/status/1906365823148564901) and the [agno-agi/pal](https://github.com/agno-agi/pal) architecture.

<br />

## What It Does

Knowledge Vault is a [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skill that turns any project directory into a structured knowledge base.

```mermaid
flowchart LR
    A["Raw Sources\n(papers, articles,\nweb clips, notes)"] -->|vault ingest| B["raw/\n.manifest.json"]
    C["Obsidian\nWeb Clipper"] -->|auto| D["Clippings/"]
    D -->|vault process| B
    B -->|vault compile| E["wiki/\nsummaries/\nconcepts/\nindex.md"]
    E -->|vault query| F["Grounded\nAnswers"]
    E -->|vault lint| G["Health\nReport"]
    E -->|browse| H["Obsidian\nGraph View"]
```

**Claude maintains all wiki content. You browse and query — never edit directly.**

<br />

## Install

```bash
git clone https://github.com/Psypeal/claude-knowledge-vault.git ~/.claude/skills/knowledge-vault
```

No config. No dependencies. No API keys. Just clone and go.

<br />

## Quick Start

```
> vault init
  Vault initialized at .vault/

> vault ingest https://arxiv.org/abs/1706.03762
  Ingested "Attention Is All You Need" as raw/attention-is-all-you-need.md

> vault compile
  Compiled 1 source. Extracted 4 concepts:
  self-attention, positional-encoding, multi-head-attention, transformer-architecture

> vault query How does self-attention handle variable-length sequences?
  Based on the vault: Self-attention computes pairwise relationships between all
  positions in parallel, making it inherently length-agnostic...
  Sources: [[attention-is-all-you-need]]
```

<br />

## Commands

| Command | Description |
|:--------|:------------|
| **`vault init`** | Initialize a `.vault/` knowledge base in the current project |
| **`vault ingest <source>`** | Add a raw source — URL, pasted text, or file path |
| **`vault compile`** | Compile pending sources into wiki summaries and concept articles |
| **`vault lint`** | Run 7 health checks on the wiki |
| **`vault query <question>`** | Ask a question grounded in your vault's knowledge |
| **`vault process`** | Batch: ingest all web clips + compile everything |
| **`vault status`** | Print a quick status summary |
| **`vault agent reset`** | Clear learned retrieval patterns and start fresh |

<br />

## Project Structure

After `vault init`:

```
your-project/
  .vault/
  ├── preferences.md      User preferences (interview-generated)
  ├── agent.md            Learned retrieval intelligence (auto-maintained)
  ├── Clippings/          Obsidian Web Clipper default folder
  ├── raw/                Ingested sources with YAML frontmatter
  │   └── .manifest.json  Source registry
  ├── wiki/
  │   ├── index.md        Master routing index
  │   ├── concepts/       One article per topic (200-500 words)
  │   ├── summaries/      One summary per source
  │   ├── outputs/        Query results and lint reports
  │   └── .state.json     Compilation and lint state
  └── templates/          Frontmatter skeletons
```

<br />

## Obsidian Frontend

Open `.vault/` as an Obsidian vault. Zero configuration needed.

<table>
  <tr>
    <td><strong>Graph View</strong></td>
    <td>Visualize concept connections via <code>[[wikilinks]]</code></td>
  </tr>
  <tr>
    <td><strong>Backlinks</strong></td>
    <td>See every article referencing a concept</td>
  </tr>
  <tr>
    <td><strong>Search</strong></td>
    <td>Full-text search across all articles</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td>Browse by YAML tags across all sources</td>
  </tr>
  <tr>
    <td><strong>Web Clipper</strong></td>
    <td>Clip from browser &#8594; auto-lands in <code>Clippings/</code> &#8594; <code>vault process</code></td>
  </tr>
</table>

<br />

## Personalized Preferences

During `vault init`, Claude interviews you about your vault's domain and priorities:

```
> vault init
  Vault initialized at .vault/

  Let me configure your vault preferences.

  What domain is this vault for?
> Biomedical research — neuroimaging and neurodegeneration

  What sources will you mainly use?
> Papers from PubMed, review articles, and meeting notes

  Any priority rules for sources?
> Peer-reviewed > preprints > blog posts. Prioritize longitudinal studies.

  How granular should concepts be?
> Balanced — not too broad, not too narrow

  Any special compilation instructions?
> Always extract methodology and sample size. Note statistical methods used.

  Preferences saved to .vault/preferences.md
```

This creates `.vault/preferences.md` — Claude reads it at the start of **every** vault operation. It shapes how sources are summarized, which concepts are extracted, and how queries are answered.

You can edit `preferences.md` manually anytime. Claude always picks up the latest version.

<br />

## 3-Tier Query Routing

Queries stay efficient at any vault size. Claude never loads everything — it reads the index, picks what's relevant, and drills down only when needed.

```
Tier 1  ─────  wiki/index.md           Always read first (one-line per entry)
                    │
Tier 2  ─────  summaries/ + concepts/  Read relevant matches (200-500 words each)
                    │
Tier 3  ─────  raw/                    Full source text (only when depth needed)
```

<br />

## Compounding Knowledge

Every query can make the vault smarter. When you ask a question, Claude automatically classifies the answer and decides whether it enriches the knowledge graph.

```mermaid
flowchart TD
    Q["vault query"] --> A["Compose answer\nfrom vault sources"]
    A --> D{"Dedup check:\nalready answered?"}
    D -->|yes| S1["Reference existing output\n(no duplicate filed)"]
    D -->|no| C{"Classify"}
    C -->|"2+ sources,\nnew relationship,\nevidence-backed"| SYN["**Synthesize**"]
    C -->|"200+ words or\n3+ concepts"| REC["**Record**"]
    C -->|"single source\nor simple lookup"| SKIP["**Skip**"]
    SYN --> F1["File to wiki/outputs/\n+ update concept graph"]
    REC --> F2["File to wiki/outputs/"]
    SKIP --> F3["Answer only\n(nothing filed)"]

    style SYN fill:#2d6a4f,color:#fff
    style REC fill:#1d3557,color:#fff
    style SKIP fill:#6c757d,color:#fff
```

### The three tiers

| Tier | When | What happens | Example |
|:-----|:-----|:-------------|:--------|
| **Synthesize** | Answer connects 2+ sources and reveals a relationship not already in the graph | Files the answer AND updates concept `related` fields in both directions | *"How do transformers compare to RNNs?"* draws from two papers, links `transformer-architecture` ↔ `recurrent-networks` |
| **Record** | Substantial analysis but no new connections | Files the answer for future reference | *"Summarize what we know about attention"* — useful reference, but concepts already linked |
| **Skip** | Simple lookup or already answered | Answers without filing | *"Which sources mention positional encoding?"* — quick factual lookup |

### Connection strength

Not all connections are equal. When a Synthesize query discovers a new relationship, it gets a strength rating:

| Strength | Criteria | Graph impact |
|:---------|:---------|:-------------|
| **Strong** | Supported by 2+ independent sources with direct evidence | Added to concept graph |
| **Moderate** | Supported by 1 source with clear evidence | Added to concept graph with note |
| **Weak** | Logically inferred but not directly stated in sources | Recorded in output only — not added to graph until confirmed by a future source |

### Safeguards

- **Deduplication**: Before filing, checks if an existing output already covers the same question or connection
- **Graph density cap**: Max 8 `related` entries per concept — new connections only replace weaker ones
- **Weak connections quarantined**: Speculative links stay in outputs, not in the concept graph, until confirmed

This means the concept graph stays clean and high-signal. Each deep query strengthens it. Shallow queries pass through without noise.

<br />

## Lint Checks

`vault lint` runs 7 health checks to keep your knowledge base consistent:

| Check | What it catches | Severity |
|:------|:----------------|:---------|
| **Contradictions** | Conflicting claims across different sources | Critical |
| **Stale articles** | Concepts not updated after new sources added | Warning |
| **Missing concepts** | Referenced via `[[wikilink]]` but no article exists | Warning |
| **Orphaned articles** | Concept articles with no sources linked | Warning |
| **Thin articles** | Concept articles under 100 words | Suggestion |
| **Duplicates** | Overlapping concept coverage | Warning |
| **Gap analysis** | Missing topics that would strengthen the knowledge graph | Suggestion |
| **Agent staleness** | agent.md references deleted concepts or sources | Warning |

<br />

## Smart Agent

The vault includes a self-improving retrieval agent (`.vault/agent.md`) that learns from your queries and gets smarter over time.

```mermaid
flowchart LR
    Q["Query"] --> A["agent.md\nsuggests articles"]
    A --> R["Claude reads\npriority articles"]
    R --> ANS["Answer"]
    ANS --> E["Evaluate:\nwhat was useful?"]
    E --> U["Update agent.md\nreinforce/expand/decay"]
    U -.->|next session| A
```

### What it learns

| Section | Max | What it tracks |
|:--------|:----|:---------------|
| **Concept Clusters** | 8 | Groups of concepts frequently queried together |
| **Query Patterns** | 10 | Maps question types to the specific articles that answer them |
| **Source Signals** | 15 | Which sources are most frequently useful and for what |
| **Corrections** | 5 | Retrieval mistakes to avoid repeating |

### How it saves tokens

Without the agent, every query scans the full index and reads 6-8 candidate articles. With the agent, Claude jumps directly to the 2-3 articles that matter.

| Vault size | Agent cost | Savings per query | Net savings |
|:-----------|:-----------|:-----------------|:------------|
| 3 sources | ~225 tokens | ~500 tokens | ~275 tokens |
| 8 sources | ~600 tokens | ~2,500 tokens | ~1,900 tokens |
| 15 sources | ~1,000 tokens | ~4,450 tokens | ~3,450 tokens |

### Safeguards

- **Bounded**: 6,000 character hard ceiling (~1,000 tokens max read cost)
- **Advisory only**: Never overrides `index.md` — only prioritizes which articles to read first
- **Cold start threshold**: Not activated until 3+ queries or 5+ compiled sources
- **Exponential decay**: Every 20 queries, hit counts halve — recent patterns outweigh old ones
- **Self-cleaning**: `vault lint` detects and removes stale references
- **Reset**: `vault agent reset` clears all learned patterns if needed

<br />

## File Format

All files use YAML frontmatter + Markdown — fully Obsidian-compatible:

```yaml
---
title: "Attention Is All You Need"
source: "https://arxiv.org/abs/1706.03762"
type: paper                              # paper | article | repo | dataset
ingested: "2026-04-03T14:22:00Z"        #   meeting | notes | clip
tags: [transformers, attention]
compiled: false
---

Content body here.
```

<br />

## Comparison

| | **Knowledge Vault** | **[agno-agi/pal](https://github.com/agno-agi/pal)** |
|:---|:---|:---|
| **Runtime** | Claude Code (your terminal) | FastAPI + Docker |
| **Storage** | Markdown + JSON | PostgreSQL + files |
| **Setup** | `git clone` one folder | Docker Compose + API keys |
| **Scope** | Per-project | Global personal agent |
| **Dependencies** | None | PostgreSQL, OpenAI API |

<br />

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) v2.0+
- `python3` (for JSON updates in helper scripts)
- [Obsidian](https://obsidian.md) *(optional, for browsing)*

<br />

## Credits

- [Andrej Karpathy](https://x.com/karpathy/status/1906365823148564901) — LLM knowledge base compilation concept
- [agno-agi/pal](https://github.com/agno-agi/pal) — manifest tracking, YAML schemas, linting architecture

## License

[MIT](LICENSE)
