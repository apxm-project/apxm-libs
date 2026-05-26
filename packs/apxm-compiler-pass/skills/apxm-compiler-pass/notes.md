# apxm-compiler-pass — entry flow design

The skill is a *guided scaffolder*. It produces the four touch-points a
new AIS/MLIR pass requires and registers them in the canonical
pipeline. It does not run the pass itself — that is the test harness's
job.

## Touch-points the scaffold produces

1. **TableGen op or attribute** (only if the pass introduces a new op
   or attr).
   - File under `crates/core/apxm-core/src/dialect/ais/*.td`.
   - Canonical attribute name registered in the apxm-core enum first;
     the `.td` then references the enum, never a duplicated literal.
2. **C++ shim** for the TableGen-emitted op definition (when needed).
3. **Rust handler** under
   `crates/compiler/apxm-compiler/src/passes/<pass_name>.rs`.
4. **Pipeline registration** in
   `crates/compiler/apxm-compiler/src/passes/pipeline.rs::build_pass_list()`.
   The scaffold appends a single new entry; it never reorders existing
   passes silently — reordering requires an explicit operator step
   because order changes affect downstream invariants.
5. **Unit-test fixture** under
   `crates/compiler/apxm-compiler/tests/passes/<pass_name>/`.
   IR-in / IR-out pair, asserted with a goldenfile diff.

## Decision tree

1. **Pass intent** (`pass_intent` input) routes to one of three
   scaffold templates: *fold*, *hoist*, or *rewrite*. Each template
   pre-fills the visitor pattern, the worklist behaviour, and a
   default test fixture shape.
2. **`target_op`** (optional) — narrows the visitor signature so the
   scaffold matches only that op by default. Without it, the visitor
   walks the entire AIS dialect.

## Required cadence (always surfaced in the scaffold output)

After editing any `.td`:

```bash
dekk apxm build-dialect   # rebuild MLIR (TableGen + C++ + Rust)
dekk apxm codegen         # regenerate Python frontend bindings
```

Skipping either produces silent type drift between the Rust runtime,
the Python frontend, and the MLIR layer.

## Why no LLM call in the entry flow

Scaffolding is deterministic. The hard part of a compiler pass — the
rewriting logic — is the operator's domain. The skill's job is to
land all four touch-points in the right place so the pass is
discoverable, registered, and tested.

## Hard contracts surfaced in the scaffold

- The canonical pass list lives in one place: `build_pass_list()`.
  Adding a pass anywhere else means it never runs.
- Attribute names resolve through the apxm-core enum. The
  `feedback_attribute_dual_naming` incident is the cautionary tale.
- AIS ops are defined in apxm-core only. The compiler crate is a
  consumer, never a definer.
