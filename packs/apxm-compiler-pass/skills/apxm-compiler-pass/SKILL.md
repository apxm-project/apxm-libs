---
name: apxm-compiler-pass
description: Build or debug an AIS/MLIR compiler pass — TableGen op definition, C++ shim, Rust handler, and registration in build_pass_list().
fallback: read crates/compiler/apxm-compiler/src/passes/
---

# APXM Compiler Pass

Use this skill when adding, modifying, or debugging a pass in the
APXM compiler pipeline. The pipeline single source of truth is
`crates/compiler/apxm-compiler/src/passes/pipeline.rs::build_pass_list()`.

## Scaffold status

Not yet implemented — `skill.air` and `skill.apxmobj` are absent.

## Key reminders (regardless of skill state)

- Editing any `.td` file requires `dekk apxm build-dialect` **then**
  `dekk apxm codegen` before Rust or Python will see the change.
- Add new passes to `build_pass_list()`; never bypass it.
- Attribute names go through the canonical enum in `apxm-core` —
  never duplicate literals in passes.
