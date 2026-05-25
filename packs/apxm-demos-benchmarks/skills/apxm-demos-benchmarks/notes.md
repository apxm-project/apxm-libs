# apxm-demos-benchmarks — entry flow design

The skill is a *templater plus a decision tree*. It produces scaffolds
the operator then completes by hand; it does not execute benchmarks
itself (that's the job of the driver script it scaffolds).

## Decision tree

1. **Host repo selection** (`host_repo` input).
   - `apxm-eval` (default): paper-bound, prereg required, claim card
     produced.
   - `apxm`: runtime-internal microbenchmark, no prereg, no claim card
     (e.g. compiler-pass latency micro, scheduler unit perf).
2. **Workload family** (derived from `intended_claim`).
   - Latency parity / regression: `latency-paired-arm` template.
   - Throughput uplift: `throughput-sweep` template.
   - Cache reuse: `cache-reuse-paired` template.
   - Dispatch correctness: `dispatch-correctness` template.
3. **Preregistration template** (only when `host_repo == apxm-eval`).
   - Maps from workload-family → existing prereg template under
     `apxm-eval/docs/preregistrations/_templates/`.
4. **Output bucket**.
   - All driver scripts resolve their write path via
     `apxm.contract.build_layout(__file__).evaluation_scenario(workload_name)`.

## Output scaffold layout

```
apxm-eval/
  docs/preregistrations/<UTC>-<workload>.md           # from template
  examples/python/benchmarks/<workload>/
    __init__.py
    run.py                                            # driver
    workload.py                                       # workload definition
    README.md                                         # what this proves
  docs/claims/<workload>.md                           # stub claim card
```

## Why no LLM call in the entry flow

Template instantiation is deterministic. The only place an LLM would
help is in *writing the workload definition itself*, and that is the
operator's job — the skill's job is to make sure all the bookkeeping
files exist in the right place with the right cross-references.

## Hard contracts surfaced in the scaffold

- `apxm.contract.build_layout(__file__)` (never raw `os.path`).
- Cache salt per `(arm, opt)` for paired-arm benchmarks.
- `dekk apxm vllm check-no-legacy --strict` in the driver's CI block.
- No literal `8916` port; ports come from the allocator.
