# apxm-author-python — entry flow design

The skill is a *templater plus a guided decision tree*. It produces a
Python workflow scaffold rooted in the GraphRecorder DSL plus the
tests + codegen reload steps the operator needs to apply by hand.

## Decision tree

1. **Target location** (`target_path` input or inferred).
   - `examples/python/<name>/`: canonical demonstrator pattern, lives
     next to its README and a CI smoke test.
   - `tests/python/<name>_test.py`: pytest-driven workflow used as a
     regression check, no example README.
   - Anywhere else: the scaffold refuses and asks the operator to pick
     one of the two canonical homes — keeps the frontend examples
     surface coherent.
2. **DSL surface** (derived from `task`).
   - `@compile` + plain function: simplest scaffold, single entry flow.
   - `GraphRecorder` builder: when the operator needs to inspect or
     mutate the AIR before compile.
   - Agent + team handles: when the workflow composes multiple skills.
3. **Codegen reload** (always emitted).
   - If `task` mentions a new op or attribute, the scaffold inserts a
     reminder block: edit the `.td`, then run `dekk apxm build-dialect`
     **then** `dekk apxm codegen` before the Python frontend will see
     the change. Skipping either produces silent type drift.

## Output scaffold layout

```
<target_path>/
  __init__.py
  workflow.py                       # @compile / GraphRecorder entry
  README.md                         # what this workflow demonstrates
test/                               # only when target_path is examples/
  test_<name>_smoke.py              # import + compile smoke
```

## Why no LLM call in the entry flow

Template instantiation is deterministic. The interesting modelling
work — choosing how to factor the user's workflow into nodes — is the
operator's job. The skill's job is to make sure the frontend
boilerplate (imports, `@compile` decoration, codegen reload reminder)
lands consistently across examples.

## Hard contracts surfaced in the scaffold

- `from apxm import compile, GraphRecorder` — never reach into private
  submodules.
- `apxm.contract.build_layout(__file__)` for any path resolution the
  workflow needs at runtime.
- `dekk apxm test-python-frontend` is the canonical post-edit check;
  the scaffold's CI block invokes it, never raw `pytest`.
