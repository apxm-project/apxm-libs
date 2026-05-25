---
name: obra-superpowers-finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and you need to decide how to integrate the work - guides completion of development work by presenting stru…
fallback: read upstream/SKILL.md and execute the workflow as written
---

# Finishing A Development Branch — obra/superpowers port

This is an APXM-AIR port of the obra/superpowers `finishing-a-development-branch` skill.

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
