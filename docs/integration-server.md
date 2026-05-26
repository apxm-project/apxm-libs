# Integration with `apxm-server`

This page documents how `apxm-libs` packs are *consumed* by
`apxm-server`. The server itself, including its full REST surface and
internal implementation, is documented in apxm core — see
[`apxm-project/apxm/crates/tools/apxm-server/README.md`](https://github.com/apxm-project/apxm/blob/main/crates/tools/apxm-server/README.md).
The pack format lives in [`architecture.md`](architecture.md); the
MCP wrapping lives in [`integration-mcp.md`](integration-mcp.md).

## Identity contract

Skill identity on every API surface is `skill_id` plus `version`,
both produced from a pack's `SkillManifest`. `display_name` is for
UI text and is never an identifier. The server is the single owner of
discovery: every other tool (GUI, CLI inspection commands) reads
through the server's endpoints, so manifest interpretation cannot
diverge.

## Skill-root configuration

`apxm-server` discovers packs by scanning configured roots. There is
no implicit scan, no client-supplied path, and no merge with arbitrary
host filesystems. Discovery sources:

1. Repeated `--skill-root <path>` flags at server startup.
2. `APXM_SKILLS_PATH` environment fallback (colon-separated).
3. Auto-discovery of `~/.apxm/libs/packs/` (user install of this
   repo).
4. Auto-discovery of a sibling `apxm-libs/packs/` directory (sibling
   clone of this repo next to apxm core).
5. The server-bundled pack root (a deterministic default, useful only
   for built-in/test packs).

REST callers cannot pass arbitrary roots or paths. `GET /v1/skills`
never accepts a `root=...` query parameter.

## REST surface

### Implemented

| Endpoint | Purpose |
| --- | --- |
| `GET /v1/skills` | List discovered packs (manifest, source metadata, paths, hashes, capability requirements, compile status). |
| `GET /v1/skills/{id}` | Return one pack's manifest, source metadata, hashes, capability requirements, and status. |
| `POST /v1/skills/{id}/validate` | Re-run validation for an installed pack and return structured failures. |
| `POST /v1/skills/{id}/execute` | Execute a precompiled, hash-validated, static `skill.apxmobj` under APXM-owned sessions. |
| `POST /v1/skills/{id}/execute/stream` | Execute a static pack and stream runtime events plus skill start/complete events. |
| `GET /v1/executions/{execution_id}` | Return an in-memory skill execution status/result record. |
| `GET /v1/executions/{execution_id}/nodes/{node_id}` | Return recorded node output detail for a skill execution. |

### Future

| Endpoint | Purpose |
| --- | --- |
| `POST /v1/skills/{id}/compile` | Compile `skill.air` to `.apxmobj`, with explicit opt level and target. Admin/dev only; unavailable in locked-down skill-server mode. |
| `GET /v1/skills/{id}/artifact` | Return artifact metadata or download handle. |
| Persistent execution store | Retain skill execution records beyond the current server process. |
| Rich node detail | Include node metrics, prompts, redacted summaries, and provenance beyond the current recorded output values. |

## Execution sequence

`POST /v1/skills/{id}/execute` runs this sequence:

```
resolve skill id (with optional @version)
  -> validate manifest and artifact hash
  -> Artifact::from_bytes
  -> find @entry DAG
  -> validate args against manifest and entry params
  -> create APXM-owned skill session dir
  -> create in-memory execution record
  -> Runtime::execute_artifact_with_session_and_emitter
  -> return execution id, result, stats, and session path
```

What's enforced today (the static slice):

- Only manifest-identified precompiled artifacts from server-owned
  skill roots are admitted.
- Raw AIR is rejected. Raw AIR is dev-only on `/v1/execute`.
- Client-provided artifact paths are rejected.
- Client-provided session roots are rejected. Sessions live under
  APXM-owned storage.
- Symlinked artifacts are rejected.
- Missing or mismatched artifact hashes are rejected.
- Entry-flow mismatches are rejected.
- Invalid session ids are rejected.
- Token budgets and timeout limits are required for every call.
- `INV_TOOL` nodes are admitted only when the manifest declares the
  capability/tool and the capability is registered in the runtime.
- When the manifest `side_effect_policy` is omitted or `read_only`,
  admitted capabilities must be read-only.
- When the policy is `sandboxed`, side-effectful capabilities must
  declare sandbox execution and pass sandbox preflight.
- Python-backed `INV_TOOL` handlers are rejected.
- `SchedulerConfig.collect_all_outputs = true` is required for skill
  executions that promise node-output inspection.

The streaming endpoint emits skill start/runtime/complete events on
SSE and records typed `node_output` and `node_metrics` events through
`EmitterAdapter`. `node_output` events carry summary/hash/redaction
metadata instead of raw JSON values; full values stay in session files
when policy allows.

## Execution records

`apxm-server` keeps an in-memory `ExecutionStore`. Each entry is
snapshotted to `executions/{execution_id}.json` inside the APXM-owned
skill session directory so that `GET /v1/executions/{execution_id}`
and `.../nodes/{node_id}` resolve from the store rather than scanning
arbitrary client-supplied paths.

Runtime events and persisted execution records emitted by server-owned
skill runs carry `skill_id`, `skill_version`, entry-flow, and artifact
hash provenance. Nested parent-skill provenance, reloadable execution
indexes, and full scheduler replay remain gated work (see G1 / G6 in
[`backlog.md`](backlog.md)).

## Loading modes from the server's perspective

The pack-level loading mode discussion lives in
[`architecture.md`](architecture.md). What the server sees:

- **Static** — pack ships `skill.apxmobj`. Server validates the
  embedded `apxm.skill_manifest.v1` section against `skill.toml`,
  verifies the artifact hash, and admits. This is the only mode
  available on the agent-facing skill endpoints today.
- **Hybrid** — pack ships `skill.air` only. Server discovers and
  validates statically; compile-on-first-use is gated on the
  `POST /v1/skills/{id}/compile` endpoint and content-hash-keyed
  cache landing.
- **Dynamic** — request-time discovery, validation, compile, and
  execute. This requires explicit capability policy, fail-closed
  safety checks, and a measured cold/warm load story. Not on the v1
  path.

## Agent-facing boundary discipline

The skill server is **narrower** than the developer execution API.
`/v1/execute` remains as a dev/debug endpoint for raw AIR, but
agent-facing clients (Codex, Claude Code, MCP, etc.) call skills by
manifest identity only. Required guardrails before exposing skill
execution to agents:

- Do not accept arbitrary AIR on `/v1/skills/{id}/execute`.
- Do not let clients choose arbitrary `session_root`.
- Require token budgets and timeout limits for every skill call.
- Validate JSON/object arguments against the skill ABI before
  execution.
- Reject missing or undeclared capabilities before runtime admission.
- Treat `/v1/capabilities/register` as admin-only or disabled in
  skill-server mode.
- Do not expose every skill as an MCP tool by default. Use one
  generic `apxm_skill_call` MCP tool first, with server-side policy
  checks.
- Prefer OS-level sandbox backends (bubblewrap or stronger) for
  side-effectful skills. The process fallback is policy-only
  isolation and is reported as degraded.
- Add auth before binding the server outside a trusted localhost or
  dev context. Default CORS is permissive and should be tightened
  before public exposure.

## Runtime initialization

A pack behaves identically when invoked through the server, through
the driver, or through a CLI smoke test. Capability admission,
sandbox routing, ACP agent registry, and inner-plan linkage are all
identical across entry points — there is no "server-only" runtime
shape that packs need to anticipate. The shared runtime-builder that
guarantees this parity lives in apxm core; see the apxm-server README
linked at the top of this page.

## Session output

Every server-owned skill run writes a session directory under
APXM-owned storage. The full schema is owned by apxm core; the subset
a pack author needs to know about looks like:

```
sessions/<skill_run_id>/
  manifest.json
  input.air                # or input-artifact.json for artifact runs
  results.json
  metrics.json
  node_statuses.json
  trace.ndjson
  live.json
  nodes/<node_id>/
    node.json
    live.json
    status.json
    metrics.json
    trace.ndjson
    output.json
    prompt.txt
    response.txt
```

For top-level skill runs (the static path), this layout is complete
today. For nested skill runs (parent calls child via `WORKFLOW_SPAWN`
artifact path or `FLOW_CALL`), per-node directories can be missing
because the driver does not always pass reconstructed artifact graph
metadata into the child session emitter — closing that gap is
[`backlog.md`](backlog.md) G3 / G4.

## What the server does not yet do

- It does not expose every pack as a per-skill MCP tool. One generic
  `apxm_skill_call` with policy is the v1 boundary.
- It does not retain execution records across server restarts. The
  on-disk snapshots exist; the reloadable index is gated.
- It does not yet attach nested parent-skill provenance to event
  metadata (G1 remainder).
- It does not yet checkpoint+replay full scheduler state. The current
  `CHECKPOINT`, `PAUSE`, and `RESUME` ops are useful control-flow
  pieces but are not scheduler snapshots (G6).

Each of these is tracked in [`backlog.md`](backlog.md) with an
acceptance test.
