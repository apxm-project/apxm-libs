---
name: obra-superpowers-verification-before-completion
description: Use when about to claim work is complete, fixed, or passing, before committing or creating PRs - requires running verification commands and confirming output be…
fallback: read upstream/SKILL.md and execute the workflow as written
---

# Verification Before Completion — obra/superpowers port

This is an APXM-AIR port of the obra/superpowers `verification-before-completion` skill.

The upstream markdown (kept verbatim under `upstream/SKILL.md`) is the
source of truth for behavior. The APXM port adds a typed AIR graph so
the runtime can:

- dispatch CPU-cheap planning nodes separately from GPU-heavy synthesis,
- fold redundant LLM calls across cache-reuse groups,
- fan out independent analysis steps,
- replay any node from cached intermediates,
- enforce capability gates per node.

See `notes.md` for the markdown → AIR translation map.

## Status

Scaffold. `skill.air` not yet authored.
