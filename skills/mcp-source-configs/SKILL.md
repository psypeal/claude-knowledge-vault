---
name: mcp-source-configs
description: Configuration templates for research MCP servers used by the knowledge vault. Internal skill used by /vault:setup-sources and /vault:collect.
user-invocable: false
---

# MCP Source Configurations

Server-by-server configuration details for research MCP servers that feed the knowledge vault. Each entry documents how to detect, install, and use the server, and how its results map to the vault's raw source format.

## 1. PubMed (Claude.ai Built-in)

| Field | Value |
|-------|-------|
| **ID** | `pubmed-builtin` |
| **Type** | builtin |
| **Add command** | None -- already available if user has Claude.ai subscription |
| **API key** | Not needed |
| **Detection** | Check `~/.claude/settings.json` permissions allow list for `PubMed` |

**Available tools:**
- `mcp__claude_ai_PubMed__search_articles` -- search by keywords, returns article list
- `mcp__claude_ai_PubMed__get_article_metadata` -- get title, authors, abstract, DOI, MeSH terms
- `mcp__claude_ai_PubMed__get_full_text_article` -- retrieve full text (when available via PMC)
- `mcp__claude_ai_PubMed__find_related_articles` -- find related articles by PMID

**Vault raw source mapping:**
- `title`: from article metadata title
- `source`: `https://pubmed.ncbi.nlm.nih.gov/<PMID>/`
- `type`: `paper`
- `tags`: from MeSH terms (select top 3-5 relevant terms)
- Content body: abstract + full text if available, otherwise abstract only

## 2. Scholar Gateway (Claude.ai Built-in)

| Field | Value |
|-------|-------|
| **ID** | `scholar-gateway` |
| **Type** | builtin |
| **Add command** | None -- already available if user has Claude.ai subscription |
| **API key** | Not needed |
| **Detection** | Check `~/.claude/settings.json` permissions allow list for `Scholar_Gateway` or `scholar-gateway` |

**Available tools:**
- `mcp__claude_ai_Scholar_Gateway__semanticSearch` -- semantic search across academic literature

**Vault raw source mapping:**
- `title`: from result title
- `source`: DOI URL or result URL
- `type`: `paper`
- `tags`: inferred from title and abstract keywords
- Content body: abstract and key excerpts from search result

## 3. Consensus

| Field | Value |
|-------|-------|
| **ID** | `consensus` |
| **Type** | http |
| **Add command** | `claude mcp add --transport http consensus https://mcp.consensus.app/mcp` |
| **API key** | Not needed |
| **Detection** | Check `.claude.json` mcpServers for `consensus` entry |

**Capabilities:**
- Academic research consensus engine
- Returns synthesized findings with source citations
- Particularly strong for biomedical and social science research questions

**Vault raw source mapping:**
- `title`: from the cited paper title
- `source`: DOI or URL from Consensus result
- `type`: `paper`
- `tags`: derived from the search query terms and result domain
- Content body: Consensus summary + individual paper findings

## 4. arXiv (blazickjp/arxiv-mcp-server)

| Field | Value |
|-------|-------|
| **ID** | `arxiv-mcp-server` |
| **Type** | stdio |
| **Add command** | `claude mcp add arxiv-mcp-server -- uvx arxiv-mcp-server --storage-path .vault/raw/arxiv-papers` |
| **API key** | Not needed |
| **Prerequisites** | `uv` (Python package manager) must be installed |
| **Detection** | Check `.claude.json` mcpServers for `arxiv-mcp-server` entry |
| **GitHub** | blazickjp/arxiv-mcp-server (2.5k stars) |

**Capabilities:**
- Search arXiv papers by query
- Download and read full paper PDFs
- Storage path configurable (defaults to `.vault/raw/arxiv-papers` in the add command above)

**Vault raw source mapping:**
- `title`: from arXiv paper metadata
- `source`: `https://arxiv.org/abs/<arXiv-ID>`
- `type`: `paper`
- `tags`: from arXiv categories (e.g., cs.AI, q-bio.BM) + author-provided keywords
- Content body: abstract + extracted text from PDF (if downloaded)

## 5. Paper Search (14 Databases)

| Field | Value |
|-------|-------|
| **ID** | `paper-search` |
| **Type** | stdio |
| **Add command** | `claude mcp add paper-search -- npx -y paper-search-mcp-nodejs` |
| **API key** | Not needed for basic use |
| **Prerequisites** | Node.js must be installed |
| **Detection** | Check `.claude.json` mcpServers for `paper-search` entry |

**Covered databases:**
arXiv, PubMed, Semantic Scholar, bioRxiv, medRxiv, Crossref, CORE, OpenAlex, DOAJ, Europe PMC, Internet Archive Scholar, Fatcat, BASE, and DBLP.

**Capabilities:**
- Unified search interface across 14 academic databases
- Returns title, authors, abstract, DOI, publication date, and source database
- Broader coverage than any single-database server

**Vault raw source mapping:**
- `title`: from paper metadata title
- `source`: DOI URL (preferred) or database-specific URL
- `type`: `paper`
- `tags`: from keywords, subject categories, or database identifiers
- Content body: abstract + any available full text or extended metadata

---

## Source Detection

The script `${CLAUDE_PLUGIN_ROOT}/scripts/detect-mcp-sources.sh` checks for installed sources by:

1. **Built-in servers**: Scanning `~/.claude/settings.json` permissions allow list for PubMed and Scholar Gateway tool patterns.
2. **Local MCP servers**: Scanning `.claude.json` (project-level) and `~/.claude.json` (user-level) mcpServers for research-related server names.
3. **Available recommendations**: Listing servers not yet detected, with their add commands ready to run.

## Sources Configuration File

The vault tracks configured sources in `.vault/sources.json`. See `references/sources-json-schema.md` for the full schema.
