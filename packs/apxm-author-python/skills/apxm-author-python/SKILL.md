---
name: apxm-author-python
description: Guide for writing APXM Python frontend workflows — GraphRecorder DSL idioms, AIR inspection, codegen reload after dialect edits.
fallback: read crates/compiler/apxm-frontend/python/apxm/ + examples/python/
---

# APXM Author (Python)

Use this skill when adding or modifying a Python workflow that compiles
through the APXM frontend. Covers `@compile`, `GraphRecorder`, agent
handles, team patterns, and the post-`.td` codegen dance.

## Scaffold status

Not yet implemented. The flow design will reference:

- `crates/compiler/apxm-frontend/python/apxm/__init__.py` — public DSL.
- `examples/python/` — canonical patterns.
- `tests/test_imports.py` — minimum import smoke.
- `dekk apxm codegen` — required after editing any `.td` file.
