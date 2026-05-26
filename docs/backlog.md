# Backlog

This page tracks open gaps in the skill-library system, in priority
order. Each gap is shippable as a PR (or small PR stack) against a
named repo, with an explicit acceptance test. The runtime/server
hooks the gaps refer to live in apxm core
(`apxm-project/apxm`); the pack catalog and tooling live here.

A gap is on this page only if it blocks a use case the system already
claims to support, or it gates a claim we want to make. Items already
shipped under the multi-repo reorg (Phase R, R.0–R.10 in the historical
backlog) are not repeated here.

## Operating principles

- Start with read-only discovery and validation. Do not execute packs
  until manifest identity, hash checks, capability policy, and server
  boundaries exist.
- Execute static, precompiled `.apxmobj` packs before dynamic
  conversion or compilation.
- Keep `/v1/execute` as a developer raw-AIR endpoint. Agent-facing
  clients call skills by manifest identity.
- Make top-level skill runs observable before claiming nested
  skill-library observability.
- Do not claim checkpoint/replay until APXM has scheduler snapshots,
  not only HITL pause/resume state.
- Every benchmark or marketing claim must trace to artifacts: CSV
  rows, session metrics, compiler diagnostics, event traces, or test
  output.

## Priority map

| Priority | Track | Outcome |
| --- | --- | --- |
| P0 | Manifest and read-only registry | APXM lists and validates installed packs safely. (Shipped.) |
| P1 | Static skill execution | APXM runs precompiled, hash-validated pack artifacts with server-owned sessions. (Shipped.) |
| P1 | Typed observability | Streams and sessions expose node outputs, prompts, metrics, skill identity, and scopes. (G1, G2 in flight.) |
| P2 | Nested skill execution | Parent graphs can call child artifacts/skills and keep child evidence inspectable. (G3, G4, T3 series.) |
| P2 | Evaluation harness | A0-A4 benchmarks produce defensible rows and claim reports. (Owned by the consuming evaluation harness, not this catalog.) |
| P3 | Dynamic loading/conversion | APXM converts/compiles/caches packs safely on demand. (T5 series.) |
| P3 | Scheduler checkpoint/replay | Pack runs can pause, checkpoint, resume, and replay from scheduler state. (G6, T6 series.) |

## Gap closure backlog

The G-items each name a missing piece, the closing tasks, and the
acceptance signal.

### G1 — stable skill provenance

**Problem.** Server-owned top-level runtime events carry `skill_id`,
`skill_version`, and entry flow, but artifact metadata, session
manifests, and nested parent-skill provenance are still incomplete.

**Implementation.**

- Done: first-class skill provenance metadata on the core event
  envelope.
- Done: attach top-level server-owned skill provenance through
  `EmitterAdapter`.
- Add a shared `SkillManifest` / `SkillProvenance` model for
  artifact/session metadata.
- Add artifact section constants such as `apxm.skill_manifest.v1`.
  (Shipped in apxm-skill / apxm-artifact.)
- Preserve provenance in session manifests and metrics before
  changing core DAG wire format.
- Later, add stable skill fields to `DagMetadata` / `NodeMetadata`
  and artifact wire metadata when nested runs require it.

**Likely files (apxm core).**
`crates/orchestration/apxm-artifact/src/lib.rs`,
`crates/tools/apxm-server/src/skills.rs`,
`crates/tools/apxm-server/src/state.rs`,
`crates/orchestration/apxm-driver/src/session_output.rs`,
later: `crates/core/apxm-core/src/types/execution/{dag,node}.rs`,
later: `crates/orchestration/apxm-artifact/src/wire.rs`.

**Acceptance.**

- Loading a pack records `skill_id`, `skill_version`, artifact hash,
  opt level, and entry flow in the session manifest.
- Two versions of the same pack can be registered without metadata
  collision.
- A mismatched manifest/artifact hash rejects before execution.

### G2 — typed node-output events

**Problem.** Generic event streams now include typed redacted
`llm_prompt`, `node_output`, and `node_metrics` payloads (with
optional runtime node names), but artifact-derived node names and
nested parent scope/provenance are still missing.

**Implementation.**

- Done: core `node_output` and `node_metrics` event kinds + payloads.
- Done: `emit_node_output`, `emit_node_metrics`, `emit_llm_prompt` in
  `EmitterAdapter`.
- Done: stream summary/hash/redaction metadata instead of raw values.
- Done: optional `node_name` on `llm_prompt`, `node_output`, and
  `node_metrics` payloads when runtime metadata is available.
- Keep `skill_id` / `skill_version` / `flow_name` in event metadata
  rather than duplicating into every payload; `scope_id` already
  travels in the event envelope when set.
- Keep full values in session files when policy allows; stream
  summaries by default.

**Likely files (apxm core).**
`crates/core/apxm-core/src/events/{kind,payload}.rs`,
`crates/runtime/apxm-runtime/src/executor/{events,emitter_adapter}.rs`,
`crates/orchestration/apxm-driver/src/session_output.rs`.

**Acceptance.**

- Runtime emitter tests and skill stream tests receive typed
  `node_output`, `node_metrics`, and redacted `llm_prompt` events.
- LLM nodes emit prompt summaries and token events under the same
  node id.
- Redaction mode suppresses full values but preserves value hashes.

### G3 — child artifact session metadata

**Problem.** Child artifact workflow sessions can miss per-node
directories because the driver does not pass reconstructed artifact
graph metadata into the child session emitter.

**Implementation.**

- Reconstruct an `AirModule`-like metadata view from the child
  artifact's entry DAG or DAG list.
- Pass that metadata into `create_session_writer` and
  `create_session_emitter` for artifact-path workflow spawns.
- Ensure child artifact sessions write `input.air` or an equivalent
  `input-artifact.json` metadata file.

**Likely files (apxm core).**
`crates/orchestration/apxm-driver/src/runtime/workflow_spawn.rs`,
`crates/orchestration/apxm-driver/src/session_output.rs`,
`crates/tools/apxm-cli/src/commands/execute.rs`.

**Acceptance.**

- Parent `WORKFLOW_SPAWN artifact_path` run creates a child session.
- Child session contains per-node directories, `output.json`,
  `status.json`, and `trace.ndjson`.
- Child session records the child artifact hash and parent execution
  id.

### G4 — `FLOW_CALL` child output namespace

**Problem.** `FLOW_CALL` runs a child DAG and returns the sub-flow
result, but it does not expose child `all_outputs` /
`node_output_map` under a skill namespace.

**Implementation.**

- Propagate runtime scheduler config into child flow calls instead of
  a bare default scheduler.
- Collect child output maps when parent execution is collecting all
  outputs.
- Define the result contract for child outputs — either a structured
  `child_outputs` field or a typed output-key model. Do not force
  string namespaces into the current `u64` node-output maps.
- Store child outputs under `flow::<agent>.<flow>` or
  `skill::<skill_run_id>/<flow>`.
- Emit child output summaries through typed node-output events.

**Likely files (apxm core).**
`crates/runtime/apxm-runtime/src/executor/handlers/flow_call.rs`,
`crates/runtime/apxm-runtime/src/scheduler/dataflow.rs`,
`crates/runtime/apxm-runtime/src/executor/hooks.rs`,
`crates/runtime/apxm-runtime/src/runtime.rs`.

**Acceptance.**

- A parent graph calls a registered child flow with two
  output-producing nodes.
- Runtime result includes parent output plus child namespaced
  outputs.
- Session/effect ledger can distinguish parent node outputs from
  child flow node outputs.

### G5 — scope persistence in sessions

**Problem.** Scope ids exist in the lower-level emitter adapter and
execution context, but the session writer does not persist them as a
first-class isolation dimension.

**Implementation.**

- Implement `set_current_scope_id` / `current_scope_id` in
  `SessionEventEmitter`.
- Stamp scope id into root trace events, node trace events, session
  manifest, node metadata, and skill-run indices.
- Add a `skills/<skill_run_id>/` or `scopes/<scope_id>/` index that
  maps scopes to node ids and outputs.

**Likely files (apxm core).**
`crates/orchestration/apxm-driver/src/session_output.rs`,
`crates/runtime/apxm-runtime/src/executor/context.rs`,
`crates/runtime/apxm-runtime/src/executor/emitter_adapter.rs`,
`crates/core/apxm-core/src/events/mod.rs`.

**Acceptance.**

- Nested child execution emits a distinct scope id.
- Session manifest does not write `scope_id: None` for scoped runs.
- Concurrent runs of the same pack do not share scope ids or
  node-output indices.

### G6 — scheduler snapshot checkpointing

**Problem.** `CHECKPOINT`, `PAUSE`, and `RESUME` are useful
control-flow pieces, but they are not full scheduler-state snapshots.

**Implementation.**

- Define a scheduler checkpoint model containing token values, node
  outputs, op states, ready/running/completed queues, retry state,
  delegated/promise tokens, graph/session/skill metadata, and
  AAM/memory references.
- Add a scheduler snapshot API and a restore API.
- Make `CHECKPOINT` use scheduler snapshots rather than only handler
  inputs.
- Make `PAUSE` and `RESUME` use the same checkpoint format.
- Mark side-effectful nodes as non-replayable unless the manifest
  declares them idempotent.

**Likely files (apxm core).**
`crates/runtime/apxm-runtime/src/scheduler/{state,dataflow}.rs`,
`crates/runtime/apxm-runtime/src/executor/handlers/{checkpoint,pause,resume}.rs`,
`crates/runtime/apxm-runtime/src/aam/session.rs`.

**Acceptance.**

- Checkpoint after node N, resume, and produce the same final output
  as an uninterrupted run.
- Replay skips completed idempotent nodes and refuses to duplicate
  non-idempotent side effects.
- Missing backend/capability state fails with a clear resume error.
- Checkpoint/replay claims are blocked unless this scheduler
  snapshot evidence exists.

## Still-pending P-track work

These task families parallel the G-items above; they are the
PR-sized work units. The historical "Phase R" reorganization tasks
(R.0–R.10) shipped under the multi-repo split and are not repeated.

### T0 — read-only skill foundation

Mostly shipped (configured roots, `SkillLibrary` scanner,
`SkillManifest` parser, REST list/get/validate routes, GUI wired to
server-owned inventory). Remaining: keep the `apxm-skill` crate the
single source of truth as the schema evolves; reject any drift caught
by CI.

### T1 — static skill execution

Mostly shipped (admission contract, REST execute + stream,
in-memory execution store, MCP `apxm_skill_call`). Remaining:

- Replace the in-memory execution store with a bounded or reloadable
  index over the persisted `executions/{execution_id}.json`
  snapshots.
- Tighten the agent-facing boundary (auth before non-localhost
  exposure, CORS tightening, `/v1/capabilities/register` admin-gating
  in skill-server mode).

### T2 — typed observability

Most payloads shipped. Remaining work is the artifact-derived node
names, nested parent provenance, and session-level scope persistence
called out in G2 and G5.

### T3 — nested skill execution and evidence

Open: T3.1 (fix child artifact workflow sessions — G3), T3.2
(namespace `FLOW_CALL` child outputs — G4), T3.3 (add named skill
invocation: `WORKFLOW_SPAWN(target_kind = "skill", target = "<id>@<v>")`
and the matching `INV_TOOL(capability = "skill:<id>")` shape).

### T4 — evaluation and benchmarks

Owned by the consuming evaluation harness, not this catalog. Open items
on that side: the A0-A4 runner fixture (`checkout-context-triage` is the
seed case), claim linting, and the benchmark ladder. The pack catalog
ships independently; whatever harness consumes it picks up packs by
`skill_id@version` once the runner exists.

### T5 — dynamic loading and conversion

Open: T5.1 (skill compile endpoint, admin/dev only, content-hash
cache), T5.2 (report-first `skill-to-air` converter that fails closed
on ambiguous mappings and produces `conversion-report.json`), T5.3
(hybrid/dynamic loading with measured cold/warm timings and
disable-globally switch).

### T6 — scheduler checkpoint and replay

Open: T6.1 (scheduler snapshot definition — G6), T6.2 (unify
`CHECKPOINT`/`PAUSE`/`RESUME` around the snapshot), T6.3 (replay
modes: `inspect`, `resume`, `replay-deterministic`, `replay-live`).

## Clear path forward

The sequencing principle: execute static, reviewed pack artifacts
first; add named dynamic loading only after the manifest, server,
sandbox, and observability contracts are real.

### Step 1 — Manifest, not loader

Already shipped. `crates/core/apxm-skill` owns the schema,
hash/validation primitives, and provenance types. `pack.toml`
(this repo) layers provenance on top. Validator
(`tools/validate_pack.py`) confirms both.

### Step 2 — Read-only skill registry

Already shipped. `GET /v1/skills`, `GET /v1/skills/{id}`,
`POST /v1/skills/{id}/validate`, with `--skill-root` /
`APXM_SKILLS_PATH` configuration and GUI consuming the server model.

### Step 3 — Execute static top-level pack artifacts

Already shipped. `POST /v1/skills/{id}/execute` and `.../execute/stream`,
`GET /v1/executions/{id}` and `.../nodes/{id}`. Remaining: bounded
or reloadable execution index, raw-AIR rejection guard, required
`SchedulerConfig.collect_all_outputs = true` for output-promising
skills, consistent runtime-builder init between driver and server
(landed via `runtime_setup.rs`).

### Step 3.5 — Harden the agent-facing server boundary

Mostly shipped. Remaining: auth before non-localhost binding;
tighten default CORS for shipped images; admin-gate
`/v1/capabilities/register` in skill-server mode; treat the process
sandbox fallback as degraded in operator output.

### Step 4 — Make node outputs first-class events

Mostly shipped (G2 above). Remaining: artifact-derived node names,
nested parent provenance, ensure root and per-node `trace.ndjson`
include the typed events when emitted.

### Step 5 — Add skill identity to artifacts and sessions

Shipped at the artifact section level (`apxm.skill_manifest.v1`);
remaining work is the session/DAG/node-metadata propagation captured
in G1 and G5.

### Step 6 — Nested and named skill invocation

Open (G3, G4, T3.3). Sequenced after Step 5 lands so child sessions
can be attributed to their parent run.

### Step 7 — Real skill checkpointing

Open (G6, T6 series). This is the last major claim, not the first.
Current `CHECKPOINT`/`PAUSE`/`RESUME` are useful but not
scheduler-state snapshots.

### Step 8 — Run the A0-A4 skill evaluation

Owned by the consuming evaluation harness, not this catalog. The first
fixture is `checkout-context-triage`. Success criteria: A3 preserves A1
correctness; A4 preserves A3 correctness; A4 has artifact-backed
evidence of fewer calls/tokens or eliminated ops; every claim traces
to CSV rows, session metrics, compiler diagnostics, or trace
artifacts.

## Definition of done for the first public claim

APXM can claim "static compiled skills are discoverable, validated,
executable, and observable" only when:

- `GET /v1/skills` and `GET /v1/skills/{id}` work from the
  server-owned registry.
- A static hash-validated pack artifact runs through
  `/v1/skills/{id}/execute`.
- The server refuses raw AIR on the skill endpoint.
- The server creates APXM-owned session output.
- Node status and output evidence are complete for output-producing
  nodes.
- Typed event streams include node outputs or redacted summaries.
- Missing capabilities and hash mismatches fail before runtime
  execution.
- A benchmark report from the consuming evaluation harness includes
  A0-A4 rows or explicitly scopes the claim to A3/A4.
- The consuming harness's claim linter passes.

## Open questions

- What is the stable APXM skill ABI beyond `inputs`, `outputs`,
  `required_capabilities`, `allowed_tools`, `side_effect_policy`,
  `isolation_policy`, and approval policy?
- Should skill-library state live in `apxm-driver`, `apxm-runtime`, a
  new orchestration crate, or stay in `apxm-server` and be factored
  out later?
- How should APXM represent intentionally judgment-heavy steps: PLAN
  nodes, autonomous zones, or host-agent callbacks behind typed
  boundaries?
- Are scripts inside source skills runtime capabilities,
  conversion-time helpers, or both?
- What safety policy applies to dynamically loaded packs that include
  shell scripts?
- How should remote/marketplace pack trust be represented in
  manifests?
