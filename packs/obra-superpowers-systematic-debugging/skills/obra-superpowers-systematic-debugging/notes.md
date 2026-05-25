# Translation notes: systematic-debugging

Maps the upstream 4-phase process to the typed AIR graph in
`skill.air`. The Iron Law ("NO FIXES WITHOUT ROOT CAUSE FIRST") is
enforced by a `validate_root_cause_established` gate before any
fix-proposal node fires.

## Upstream → AIR

| Upstream phase | AIR node(s) |
|---|---|
| Phase 1: Read error messages | `read_error_messages` (deterministic) |
| Phase 1: Reproduce consistently | `reproduce_consistently` (CPU) |
| Phase 1: Stack-trace / change / history analysis | `analyze_*` × 3, parallel fan-out (CPU) |
| Phase 1 closeout: identify root cause | `identify_root_cause` (CPU) + `validate_root_cause_established` gate |
| Phase 2: Pattern check | `analyze_pattern_match` (CPU) |
| Phase 3: Fix design | `propose_fix` × 2 (minimal vs defense-in-depth), parallel fan-out (GPU) |
| Phase 4: Verification plan | `plan_verification` (CPU) + `synthesize_fix_proposal` (GPU) |

## Why a graph beats the markdown

- The Iron Law moves from a prose admonition to a hard runtime gate;
  no fix-proposal node can run until root cause is established.
- Phase 1 analyses are independent — fan-out cuts wall-clock latency
  vs serialized prose flow.
- The two fix strategies (minimal vs defense-in-depth) run in
  parallel; the synthesizer chooses between them with full context.
- GPU-heavy fix-proposal calls are gated behind cheaper CPU-side
  triage; misdiagnosis can't burn synthesis tokens.

## Verification

Run the same bug report through `dekk apxm execute skill.air` and
through a host agent following `upstream/SKILL.md`. Outputs
(root-cause statement, candidate fixes, verification plan) should
match modulo phrasing.
