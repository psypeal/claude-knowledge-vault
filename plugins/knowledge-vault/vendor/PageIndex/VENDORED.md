# Vendored PageIndex

This directory is a pinned, stripped-down copy of [VectifyAI/PageIndex](https://github.com/VectifyAI/PageIndex) used by `knowledge-vault` to build per-document tree indices.

- **Upstream commit**: `dcda5656ba270cc30caaa9486a450d639e1d2081`
- **Upstream license**: MIT (see `LICENSE`)
- **What was kept**: `pageindex/`, `run_pageindex.py`, `requirements.txt`, `LICENSE`, `README.md`
- **What was stripped**: `.git/`, `.github/`, `cookbook/`, `examples/` (~50 MB of demo PDFs), `.claude/`

## Local modifications

- `pageindex/config.yaml`: default model switched from `gpt-4o-2024-11-20` to `anthropic/claude-sonnet-4-6` (routed via LiteLLM); `if_add_doc_description` flipped to `"yes"` so the vault can extract authors/year/title for slug derivation.

## Updating

To pull a newer upstream:

```bash
cd /tmp
git clone --depth 1 https://github.com/VectifyAI/PageIndex.git pi
rsync -a --delete \
  --exclude .git --exclude .github --exclude cookbook --exclude examples --exclude .claude \
  --exclude .env \
  pi/ /path/to/plugin/vendor/PageIndex/
# Then re-apply local modifications to pageindex/config.yaml.
# NOTE: --exclude .env is load-bearing — vendor/PageIndex/.env holds the user's
# ANTHROPIC_API_KEY (written by /knowledge-vault:setup-sources); deleting it
# silently disables tree builds.
```
