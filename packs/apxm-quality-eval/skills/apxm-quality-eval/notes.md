# apxm-quality-eval — entry flow design

The skill is a *fixture-runner orchestrator*. It locates the requested
fixture in the apxm-eval sibling clone, drives it end-to-end
(workload → budget → judge → claim check), and emits a structured run
record under the canonical `.apxm/evaluation/` bucket.

## Probe sequence

1. **Locate fixture**. `fixture` input resolves against the apxm-eval
   sibling clone's fixture catalog. If the sibling clone is absent,
   the skill fails fast with the missing-clone diagnostic rather than
   silently falling back to an empty fixture set.
2. **Resolve opt level**. `opt_level` defaults to the fixture's
   declared canonical level; explicit override is allowed for
   sensitivity sweeps.
3. **Resolve output bucket** via
   `apxm.contract.build_layout(__file__).evaluation_scenario(fixture)`.
   The run directory is `<bucket>/runs/<UTC>/`. Never write to
   `examples/` or repo root.
4. **Run the harness** through the apxm-eval driver. The skill never
   shells to `cargo` or `pytest` directly — Dekk wraps the harness.
5. **Budget summary**. Parse the harness's emitted budget JSON
   (latency, tokens, dollars per the fixture's declared shape).
6. **Judge verdicts**. Parse judge output and the corresponding judge
   prompts so the operator can audit the calls.
7. **Claim-check verdict**. If the fixture has a registered claim
   card, run the claim check against the run record and return its
   verdict; otherwise mark `claim_check: not-applicable`.

## Output schema

```json
{
  "run_dir": ".apxm/evaluation/<scenario>/runs/<UTC>/",
  "fixture": "...",
  "opt_level": "2",
  "budget": {"latency_ms_p95": 0, "tokens": 0, "dollars": 0},
  "judges": [{"name": "...", "verdict": "...", "prompt_path": "..."}],
  "claim_check": {"status": "pass|fail|not-applicable", "claim_id": "..."}
}
```

## Why preregistration is enforced upstream, not here

The preregistration gate lives next to the apxm-eval harness (per the
project memo on plans-as-graphs). This skill assumes a preregistered
fixture; it does not re-enforce that contract.

## Hard contracts surfaced in the output

- `apxm.contract.build_layout(__file__)` for run paths.
- Paired-arm cache salt scoping per `(arm, opt)` — the harness owns
  this, the skill verifies the fixture declares it.
- All emitted artifacts under `.apxm/evaluation/`, never elsewhere.
