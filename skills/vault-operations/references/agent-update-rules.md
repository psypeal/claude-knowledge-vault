# Post-Query Agent Update Rules

Reference document for the `.vault/agent.md` update procedure. Execute these steps after every vault query, once the answer has been composed.

## Update Steps

### a. Pattern Reinforcement

If a Query Pattern's suggested articles matched what was actually useful, increment its hit count.

### b. Pattern Expansion

If useful articles were not predicted by any pattern, update the closest matching pattern or create a new one (if under 10 slots).

### c. Pattern Decay

If a pattern's suggested articles were read but not useful, decrement its hit count. At 0 hits, evict the pattern.

### d. Cluster Discovery

If 2+ concepts were co-accessed and do not already share a cluster, create or merge into a cluster (if under 8 slots).

### e. Source Signal Update

Increment cited count for any source whose summary or raw content contributed to the answer.

### f. Correction Logging

If agent.md routing led to a wrong path (Claude had to discard and re-route), log the correction (max 5, FIFO).

### g. Stats Update

Increment `total_queries`. If no Tier 3 reads were needed, increment `cache_hits`. Otherwise increment `tier3_fallbacks`.

### h. Decay Check

Every 20 queries (when `total_queries % 20 == 0`), divide all hit counts by 2 (integer division). This implements exponential decay -- recent patterns outweigh old ones.

### i. Eviction

If any section is at capacity and a new entry is needed, evict the entry with lowest hit/cited count. If tied, evict the oldest.

## Eviction Rules

Each agent.md section has a hard capacity limit:

| Section | Max entries |
|---------|-----------|
| Concept Clusters | 8 |
| Query Patterns | 10 |
| Source Signals | 15 |
| Corrections | 5 (FIFO) |

When a section is full and a new entry must be added:
1. Find the entry with the lowest hit count (for patterns/clusters) or cited count (for source signals).
2. If two entries tie on count, evict the one with the older `last` timestamp.
3. For Corrections, always evict the oldest entry (strict FIFO).

## Decay Mechanism

Exponential decay runs every 20 queries to prevent stale patterns from dominating:

- **Trigger**: `total_queries % 20 == 0`
- **Action**: Divide all hit counts and cited counts by 2 (integer division)
- **Effect**: A pattern accessed 10 times but not recently decays to 5, then 2, then 1 -- making room for new patterns that reflect current query behavior

## Connection Strength Ratings

Used during synthesize-tier query filing to rate new connections between concepts:

| Strength | Criteria | Graph impact |
|----------|----------|-------------|
| **strong** | Supported by 2+ independent sources with direct evidence | Added to `related` in both concept articles |
| **moderate** | Supported by 1 source with clear evidence, or 2+ sources with indirect evidence | Added to `related` in both concept articles with "(moderate)" note |
| **weak** | Inferred logically but not directly stated in any source | NOT added to concept articles -- recorded in output only, flagged for future confirmation |

Write the updated `.vault/agent.md` after completing all steps.
