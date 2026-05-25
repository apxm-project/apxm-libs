---
name: apxm-design-docs
description: Edit conceptual docs under docs/design/ while pinning every factual claim to shipped code. Catches overclaim drift between aspirations and reality.
fallback: read docs/design/ directly + cross-check with git log
---

# APXM Design Docs

Use this skill when editing any document under `docs/design/`. The
skill's job is to ensure each factual claim about runtime/compiler/
server behavior cites a specific file or commit that supports it, and
that aspirational/in-flight sections are labeled as such rather than
phrased in the present tense.

## Scaffold status

Not yet implemented — `skill.air` and `skill.apxmobj` are absent.
