---
name: apxm-demos-benchmarks
description: Author a new benchmark/demo end-to-end — workload decision, preregistration template, driver-script scaffold, .apxm/ output placement, claim card stub.
fallback: read apxm-eval/docs/preregistrations/ and apxm-eval/examples/python/benchmarks/
---

# APXM Demos & Benchmarks

Use this skill when starting a new benchmark or demo workload. It
walks the decision tree (which workload family, which preregistration
template, which `.apxm/` output bucket) and emits scaffolds.

## Inputs

- `workload_name` (required): kebab-case identifier.
- `intended_claim` (required): the empirical question the benchmark
  must answer. Used to pick the preregistration template.
- `host_repo` (optional): `apxm-eval` (default) or `apxm` for
  runtime-internal microbenchmarks that do not produce paper-bound
  claims.

## Output

- `prereg_draft_path`: path to a templated preregistration under
  `docs/preregistrations/` in `apxm-eval`.
- `driver_script_path`: path to a templated driver under
  `examples/python/benchmarks/<workload>/run.py`.
- `output_layout`: the `.apxm/evaluation/<scenario>/runs/<UTC>/` path
  the driver will write to (resolved via `apxm.contract.build_layout`).
- `claim_card_stub`: optional `docs/claims/<workload>.md` skeleton.

## Hard rules

- Preregistration before claims: the prereg draft must be merged
  before the driver script can record a paper-bound run.
- Output paths must resolve through `apxm.contract.build_layout(__file__)`;
  no `examples/` or `docs/` writes from a driver.
- Paired-arm benchmarks: cache salt per `(arm, opt)`, never per
  `(iter, row)`.

## Scaffold status

Not yet implemented — `skill.air` and `skill.apxmobj` are absent. The
decision tree and template paths are captured in `notes.md`.
