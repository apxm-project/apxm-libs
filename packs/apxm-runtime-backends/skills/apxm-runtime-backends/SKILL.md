---
name: apxm-runtime-backends
description: Backend implementation guide — adding providers, threading dispatch hints to vLLM, scheduler edits, no-legacy contract enforcement.
fallback: read crates/runtime/apxm-backends/
---

# APXM Runtime Backends

Use this skill when modifying the runtime's backend layer, the
scheduler, or the vLLM dispatch surface.

## Scaffold status

Not yet implemented — `skill.air` and `skill.apxmobj` are absent.

## Hard rules

- Hard-fail at config time. Never `cfg or env or default` chains
  (rule `or-env-or-default-chain` in `check_no_legacy_vllm.py`).
- Promote contract strings to `graph_attrs::*` / `metrics_keys::*`
  constants. No literal `"reuse_group"` in handlers.
- vLLM coordination requires a cherry-pick plan against
  `apxm-rebase-v0.21.0` in `external/vllm` — never edit upstream
  files in-place.
