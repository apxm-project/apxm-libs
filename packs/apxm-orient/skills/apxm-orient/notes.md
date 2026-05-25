# apxm-orient — entry flow design

The orient skill is deterministic: it runs a fixed set of probes and
assembles a structured card. No LLM calls, no branching on model output.

## Probe sequence

1. **`dekk apxm doctor --json`** — env contract check. Surfaces
   `CARGO_TARGET_DIR`, `MLIR_DIR`, `LLM_GATEWAY_KEY` presence, vLLM
   submodule SHA. If `dekk` is missing, fall back to a partial card
   with a `degraded: true` flag.
2. **`cargo metadata --no-deps --format-version=1`** — workspace
   members. Group by the `crates/{core,compiler,runtime,tools}/`
   prefix. If `focus_area` is set, filter to crates whose path matches.
3. **`git log -n 10 --format='%h%x09%s'`** on the current branch.
   Parse conventional-commit type/scope from each subject.
4. **`git rev-parse --abbrev-ref HEAD`** + **`git rev-list --left-right
   --count @{upstream}...HEAD`** — current branch + divergence
   (0 if no upstream).
5. **Companion-repo probe**: check whether sibling directories
   `../apxm-eval` and `../apxm-libs` exist and are git repos. Report
   each as `present`, `missing`, or `not-a-repo`.

## Output schema

```json
{
  "doctor": {"status": "ok|warn|fail", "env": {...}, "vllm_sha": "..."},
  "crate_map": {"core": [...], "compiler": [...], "runtime": [...], "tools": [...]},
  "recent_commits": [{"sha": "...", "type": "...", "scope": "...", "subject": "..."}],
  "active_branch": {"name": "...", "ahead": 0, "behind": 0},
  "companion_repos": {"apxm-eval": "present", "apxm-libs": "missing"},
  "degraded": false
}
```

## Why no LLM call

The card's job is to *load context for the calling agent*. Adding an
LLM summarization step would tax the same budget the calling agent
needs for the actual task, and would risk introducing model-driven
hallucinations into what should be a verifiable factual probe.
