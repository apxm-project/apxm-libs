---
name: apxm-quality-eval
description: Run a quality-eval fixture end-to-end (fixture + budget + judge + claim check). Lives next to the apxm-eval companion repo's harness.
fallback: read tools/quality_eval/ in apxm-eval
---

# APXM Quality Eval

Use this skill to drive a single quality-eval fixture through the
harness, surface its budget + judge results, and emit a claim-check
verdict.

## Scaffold status

Not yet implemented — `skill.air` and `skill.apxmobj` are absent. The
runtime side of this skill depends on a sibling clone of
`apxm-project/apxm-eval` for the fixture catalog.
