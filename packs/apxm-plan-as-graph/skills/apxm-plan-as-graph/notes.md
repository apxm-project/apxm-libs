# AIR-node design: apxm-plan-as-graph

This skill is an original APXM pack. Its single AIR graph turns a
natural-language `task` into a typed `task_dag` JSON document that the
caller can compile and execute through APXM.

## Why a graph at all

A linear "ask the model to write a plan" call collapses three things
that should be separable:

1. Reading any caller-supplied context.
2. Dispatching the planner role that produces the AIR JSON.
3. Validating the emitted JSON against `schema.json` so downstream
   compilation does not get a malformed graph.

Splitting them into named nodes lets the runtime cache the planner
call across retries, gate compilation behind validation, and surface
a single `task_dag` field to the caller without leaking intermediate
prose.

## Node map

| Node                  | Op     | Role                                                                 |
|-----------------------|--------|----------------------------------------------------------------------|
| `read_inputs`         | cpu    | Normalize `task` + optional `context` into a single planner prompt.  |
| `emit_task_dag`       | gpu    | Dispatch the planner role; produce candidate AIR JSON.               |
| `validate_task_dag`   | cpu    | Validate against `schema.json`; one repair attempt on failure.       |
| `synthesize_summary`  | cpu    | Wrap the validated `task_dag` and metadata as the returned summary.  |

`emit_task_dag` is the only GPU node. It carries a `reuse_group` so
that repeated invocations with the same `(task, context)` pair can
fold against the prefix cache instead of re-paying decode cost.

## Capability

The skill declares `required_capabilities = ["plan_emission_v1"]`
because the planner role must understand the AIR JSON contract
described in `schema.json` and `prompt.md`. A runtime without that
capability should refuse to load the skill rather than silently fall
through to a generic planner.

## Output contract

The returned `task_dag` is the AIR JSON document the caller will pass
to `dekk apxm compile` (or the equivalent in-process call). Validation
failures surface as a single repair-request loop and, on second
failure, a clean error — never a malformed graph.
