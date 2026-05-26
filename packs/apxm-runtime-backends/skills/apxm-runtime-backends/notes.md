# apxm-runtime-backends — entry flow design

The skill is a *cross-file touch-point planner*. Backend work in APXM
spans the backend provider (`crates/runtime/apxm-backends/`), the
runtime executor that wires it in, the scheduler that picks lanes,
and — for vLLM hints — the fork in `external/vllm/`. The skill emits
the touch-point list and the contract checks the operator must run.

## Decision tree

1. **Task classification** (from `task` input).
   - *New provider* (e.g. add Anthropic): backend trait impl +
     registration + config schema entry + `apxm backend list` smoke.
   - *Dispatch hint*: graph-attrs constant + handler thread-through +
     vLLM-fork xargs surface + integration test.
   - *Scheduler edit*: scheduler policy file + no-legacy lint
     re-affirmation + paired-arm benchmark stub.
2. **Backend filter** (`backend` input, optional).
   - `llm`: provider implementations in `apxm-backends/`.
   - `local`: in-process worker pool.
   - `tool`: MCP-backed tool execution.
   - `vllm`: dispatch hints surface and the fork-coordination path.

## Touch-point template (provider example)

```
crates/runtime/apxm-backends/src/<provider>/
  mod.rs                            # trait impl
  client.rs                         # transport
  config.rs                         # ProviderConfig
crates/runtime/apxm-backends/src/registry.rs   # add to enum + dispatch
crates/runtime/apxm-runtime/src/executor.rs    # if executor needs hint
config/backends.example.toml                   # config schema entry
tests/backends/<provider>_smoke.rs             # request roundtrip
```

## vLLM-coordination path

When the task touches the vLLM dispatch surface:

1. Edit the APXM side first (graph-attrs constant, handler).
2. Write the cherry-pick plan against branch
   `apxm-rebase-v0.21.0` in `external/vllm`. Never edit upstream
   files in-place without a cherry-pick plan.
3. The `randreshg/vllm` fork holds 5 APXM commits on upstream
   v0.21.0; any new commit is a sixth.
4. Run `dekk apxm vllm check-no-legacy --strict` after the edit.

## Hard contracts surfaced in the touch-point list

- Hard-fail at config time. Never `cfg or env or default` chains
  (rule `or-env-or-default-chain`).
- Promote contract strings to `graph_attrs::*` / `metrics_keys::*`
  constants. The `feedback_attribute_dual_naming` incident is the
  cautionary tale.
- No literal `8916` port. Use the allocator or a manifest port.
- Resolver has no last-resort branch; missing backends are a
  hard-fail, not a silent skip.

## Why no LLM call in the entry flow

Touch-point planning is deterministic given the task classification.
The implementation work itself is the operator's job; the skill's
job is to make sure no touch-point gets missed.
